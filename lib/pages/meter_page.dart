import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/auth_store.dart';
import '../services/drive_store.dart';
import '../utils/formatters.dart';
import '../widgets/ad_banner.dart';
import '../widgets/horse_led.dart';
import 'ride_complete_page.dart';
import 'settings_page.dart';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:geolocator/geolocator.dart';

class MeterPage extends StatefulWidget {
  final String region;

  const MeterPage({super.key, required this.region});

  @override
  State<MeterPage> createState() => _MeterPageState();
}

class _MeterPageState extends State<MeterPage> {
  bool isDriving = false;
  bool surcharge = false;
  bool outsideCity = false;

  double distance = 0.0;
  int fare = 0;
  int speed = 0;

  // 주행 시작 시각과 경과 시간(초)
  DateTime? startTime;
  int elapsedSeconds = 0;

  Timer? timer;

  StreamSubscription<Position>? _positionStream;
  Position? _lastPosition;

  static const int baseFare = 4800;

  // ===== 시간 요금 (서울 중형택시 기준: 저속 주행 시 30초당 100원) =====
  // 속도가 lowSpeedKmh 미만(정차 포함)인 시간이 쌓이면 요금이 오릅니다.
  static const int lowSpeedKmh = 15; // 이 속도 미만이면 시간요금 대상
  static const int timeFareUnitSeconds = 30; // 몇 초마다
  static const int timeFareUnitWon = 100; // 몇 원씩 올릴지

  // GPS가 이 시간(초) 동안 들어오지 않으면 정차 중으로 보고 속도를 0으로 처리
  // (정차 중에는 위치 변화가 없어 GPS 값이 오지 않기 때문)
  static const int staleSeconds = 4;

  int lowSpeedSeconds = 0; // 저속/정지로 보낸 누적 시간(초)
  DateTime? _lastPositionTime; // GPS를 마지막으로 받은 시각

  // 주행 버튼 LED 깜빡임
  bool drivingLedOn = true;
  Timer? ledTimer;

  @override
  void initState() {
    super.initState();

    // 화면 자동 꺼짐 방지
    WakelockPlus.enable();

    _initForegroundTask();

    // 저장된 주행이 있으면 이어서 진행
    _restoreSession();

    // 주행 버튼 안의 점(LED) 깜빡이는 속도
    ledTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!mounted) return;

      if (isDriving) {
        setState(() {
          drivingLedOn = !drivingLedOn;
        });
      }
    });
  }

  // 화면 아래 안내 메시지 (필요하면 '설정 열기' 버튼 포함)
  void _showSnack(String message, {Future<bool> Function()? settingsAction}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: settingsAction == null
            ? null
            : SnackBarAction(
                label: '설정 열기',
                onPressed: () {
                  settingsAction();
                },
              ),
      ),
    );
  }

  // GPS 켜짐 여부 및 권한 체크
  Future<bool> _checkPermission() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return false;

    if (!serviceEnabled) {
      _showSnack(
        '스마트폰의 위치(GPS) 기능을 켜주세요.',
        settingsAction: Geolocator.openLocationSettings,
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!mounted) return false;

    if (permission == LocationPermission.deniedForever) {
      _showSnack(
        '위치 권한이 차단되어 있습니다. 설정에서 위치 권한을 허용해주세요.',
        settingsAction: Geolocator.openAppSettings,
      );
      return false;
    }

    if (permission == LocationPermission.denied) {
      _showSnack('주행 거리를 계산하려면 위치 권한이 필요합니다.');
      return false;
    }

    return true;
  }

  // 백그라운드(포그라운드 서비스) 설정
  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'taxi_meter',
        channelName: '택시미터 주행',
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
      ),
    );
  }

  // GPS 정확도가 이 값(m)보다 나쁘면 그 위치는 거리 계산에서 제외
  static const double maxAccuracyMeters = 30;

  // 주행 정보를 저장소에 마지막으로 저장한 시각 (너무 자주 저장하지 않기 위함)
  DateTime? _lastSavedAt;

  // 현재 주행 상태를 휴대폰 저장소에 저장
  Future<void> _saveSession() async {
    final start = startTime;
    if (start == null) return;

    await DriveStore.save(
      DriveSession(
        region: widget.region,
        startTime: start,
        surcharge: surcharge,
        outsideCity: outsideCity,
        distance: distance,
        lowSpeedSeconds: lowSpeedSeconds,
        email: AuthStore.currentEmail,
      ),
    );
  }

  // 거리 변화는 5초에 한 번만 저장
  void _saveSessionThrottled() {
    final now = DateTime.now();
    if (_lastSavedAt != null && now.difference(_lastSavedAt!).inSeconds < 5) {
      return;
    }
    _lastSavedAt = now;
    _saveSession();
  }

  // 앱이 다시 켜졌을 때 저장된 주행을 이어서 진행
  void _restoreSession() {
    final session = DriveStore.active;
    if (session == null) return;

    startTime = session.startTime;
    surcharge = session.surcharge;
    outsideCity = session.outsideCity;
    distance = session.distance;
    lowSpeedSeconds = session.lowSpeedSeconds;
    elapsedSeconds = DateTime.now().difference(session.startTime).inSeconds;
    isDriving = true;
    _calculateFare();

    _startTracking();
    _ensureForegroundService();
  }

  // 주행 시작
  // 화면과 타이머를 먼저 시작하여 서비스 시작 때문에 생기는 지연을 없앤다.
  Future<void> _startDriving() async {
    if (isDriving) return;

    final hasPermission = await _checkPermission();
    if (!hasPermission) return;

    startTime = DateTime.now();
    _lastPosition = null;
    _lastPositionTime = null;
    _lastSavedAt = null;
    lowSpeedSeconds = 0;

    setState(() {
      isDriving = true;
      fare = baseFare;
      distance = 0.0;
      speed = 0;
      elapsedSeconds = 0;
      drivingLedOn = true;
    });

    _saveSession();
    _startTracking();
    await _ensureForegroundService();
  }

  // 주행 시간 타이머 + GPS 수신 시작
  void _startTracking() {
    // 타이머는 오직 "주행 시간(초)"만 측정
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || startTime == null) return;
      setState(() {
        final int newElapsed = DateTime.now().difference(startTime!).inSeconds;
        final int passed = newElapsed - elapsedSeconds;
        elapsedSeconds = newElapsed;

        // GPS가 한동안 안 들어오면 정차 중으로 보고 속도를 0으로
        final last = _lastPositionTime;
        if (last == null ||
            DateTime.now().difference(last).inSeconds >= staleSeconds) {
          speed = 0;
        }

        // 저속/정지 시간만큼 시간요금 대상 시간을 쌓고 요금 갱신
        if (speed < lowSpeedKmh && passed > 0) {
          lowSpeedSeconds += passed;
          _calculateFare();
        }
      });
      _saveSessionThrottled();
    });

    // iOS는 백그라운드 위치 수신을 따로 허용해야 합니다.
    final LocationSettings locationSettings =
        defaultTargetPlatform == TargetPlatform.iOS
        ? AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 2,
            activityType: ActivityType.automotiveNavigation,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true,
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 2, // 2미터 이상 실제 이동 시 호출
          );

    _positionStream?.cancel();
    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          _onPosition,
          onError: (Object e) {
            debugPrint('GPS stream error: $e');
          },
        );
  }

  // GPS 위치가 들어올 때마다 속도/거리/요금 갱신
  void _onPosition(Position position) {
    if (!mounted) return;

    // GPS 신호가 들어온 시각 기록 (정차 판단용)
    _lastPositionTime = DateTime.now();

    // 오차가 큰 위치는 무시 (정차 중 GPS가 튀어 요금이 오르는 것을 방지)
    if (position.accuracy > maxAccuracyMeters) return;

    setState(() {
      // 단말기가 감지한 실제 속도 (km/h)
      final double currentSpeed = position.speed * 3.6;
      speed = currentSpeed > 0 ? currentSpeed.round() : 0;

      // 실제 좌표 이동량(m)을 km로 환산하여 누적
      if (_lastPosition != null) {
        final double movedMeters = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        // 정차 중 GPS 오차(노이즈) 필터링: 1m 초과 이동만 반영
        if (movedMeters > 1.0) {
          distance += movedMeters / 1000.0;
          _calculateFare();
        }
      }

      _lastPosition = position;
    });

    _saveSessionThrottled();
  }

  // 포그라운드 서비스(주행 중 알림) 실행. 이미 실행 중이면 그대로 둠.
  Future<void> _ensureForegroundService() async {
    try {
      await FlutterForegroundTask.requestNotificationPermission();

      if (await FlutterForegroundTask.isRunningService) return;

      await FlutterForegroundTask.startService(
        serviceTypes: [ForegroundServiceTypes.location],
        notificationTitle: '택시미터 주행 중',
        notificationText: '${widget.region} 주행이 진행 중입니다.',
      );
    } catch (e) {
      debugPrint('Foreground service error: $e');
    }
  }

  void _calculateFare() {
    double calculated = baseFare.toDouble();

    if (distance > 1.6) {
      calculated += (distance - 1.6) * 1000;
    }

    // 시간 요금: 저속/정지 시간 30초마다 100원
    calculated += (lowSpeedSeconds ~/ timeFareUnitSeconds) * timeFareUnitWon;

    if (surcharge) {
      calculated *= 1.2;
    }

    if (outsideCity) {
      calculated *= 1.3;
    }

    fare = calculated.round();
  }

  void _toggleSurcharge() {
    setState(() {
      surcharge = !surcharge;
      _calculateFare();
    });
    _saveSession();
  }

  void _toggleOutsideCity() {
    setState(() {
      outsideCity = !outsideCity;
      _calculateFare();
    });
    _saveSession();
  }

  // 종료 확인 후 실제 주행 종료
  Future<void> _finishDriving() async {
    if (!isDriving) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('주행 종료'),
          content: const Text('주행을 종료하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('종료'),
            ),
          ],
        );
      },
    );

    // 취소했거나 다이얼로그가 닫힌 경우 주행 유지
    if (confirmed != true) return;

    timer?.cancel();
    timer = null;

    _positionStream?.cancel();
    _positionStream = null;
    _lastPosition = null;

    // 저장된 주행 정보 삭제
    await DriveStore.clear();

    // 포그라운드 서비스 종료
    try {
      await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint('Foreground service stop error: $e');
    }

    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideCompletePage(
          region: widget.region,
          distance: distance,
          fare: fare,
          duration: Duration(seconds: elapsedSeconds),
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {
        isDriving = false;
        distance = 0;
        fare = 0;
        speed = 0;
        elapsedSeconds = 0;
        lowSpeedSeconds = 0;
        startTime = null;
        surcharge = false;
        outsideCity = false;
        drivingLedOn = true;
      });
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    ledTimer?.cancel();
    _positionStream?.cancel();
    WakelockPlus.disable();
    if (isDriving) {
      FlutterForegroundTask.stopService();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDriving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isDriving) {
          _showSnack('주행 중에는 나갈 수 없습니다. 먼저 주행을 종료해주세요.');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.region),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _openSettings,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      _fareDisplay(),

                      const SizedBox(height: 12),

                      HorseLed(running: isDriving, speed: speed),

                      const SizedBox(height: 12),

                      _infoDisplay(),

                      const SizedBox(height: 12),

                      _optionButtons(),

                      const SizedBox(height: 12),

                      _mainButtons(),

                      const SizedBox(height: 12),

                      _fareNoticeBox(),
                    ],
                  ),
                ),
              ),

              const AdBanner(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fareDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent, width: 2),
      ),
      child: Column(
        children: [
          const Text(
            '현재 요금',
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 62,
                height: 52,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statusSlot('할증', Colors.orange, surcharge),
                    const SizedBox(height: 4),
                    _statusSlot('시외', Colors.redAccent, outsideCity),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '₩${formatNumber(fare)}',
                    style: const TextStyle(
                      fontSize: 38,
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 62),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusSlot(String label, Color color, bool active) {
    return Opacity(
      opacity: active ? 1 : 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _optionButtons() {
    return Row(
      children: [
        Expanded(
          child: _fareOptionButton(
            title: '할증',
            active: surcharge,
            onPressed: isDriving ? _toggleSurcharge : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _fareOptionButton(
            title: '시외',
            active: outsideCity,
            onPressed: isDriving ? _toggleOutsideCity : null,
          ),
        ),
      ],
    );
  }

  Widget _fareOptionButton({
    required String title,
    required bool active,
    required VoidCallback? onPressed,
  }) {
    // 켜져 있을 때 0.5초마다 투명/원래색을 번갈아 표시 (깜빡임 효과)
    final Color textColor = active
        ? (drivingLedOn ? Colors.greenAccent : Colors.transparent)
        : Colors.grey;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        side: BorderSide(
          color: active ? Colors.greenAccent : Colors.grey.shade700,
          width: 1.5,
        ),
        backgroundColor: active
            ? Colors.greenAccent.withValues(alpha: 0.15)
            : Colors.transparent,
      ),
      child: Text(
        active ? '$title ON' : title,
        style: TextStyle(
          color: textColor, // 깜빡이는 색상 적용
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  // 거리 + 속도는 한 줄,
  // 시간은 그 아래 한 줄 전체를 사용한다.
  Widget _infoDisplay() {
    return Column(
      children: [
        // 거리 + 속도 : 기존처럼 각각 위/아래 2줄
        Row(
          children: [
            Expanded(
              child: _infoBox('거리', '${distance.toStringAsFixed(2)} km'),
            ),
            const SizedBox(width: 10),
            Expanded(child: _infoBox('속도', '$speed km/h')),
          ],
        ),

        const SizedBox(height: 8),

        // 주행시간만 예외적으로 한 줄
        _timeBox(),
      ],
    );
  }

  // 거리/속도 박스 크기
  static const double infoBoxHeight = 78;

  // 거리/속도 전용 박스
  // 제목과 값이 위/아래 2줄로 표시된다.
  Widget _infoBox(
    String title,
    String value, {
    double? width,
    double height = infoBoxHeight,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 주행시간 전용 박스
  // 화면 가로 전체를 사용하고 '주행시간  00:01:42'를 한 줄에 표시한다.
  Widget _timeBox() {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '주행시간',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 40),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatDuration(elapsedSeconds),
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mainButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: isDriving ? null : _startDriving,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDriving
                    ? Colors.green.shade900
                    : Colors.green.shade700,
                disabledBackgroundColor: Colors.green.shade900,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _statusDot(
                    color: isDriving && !drivingLedOn
                        ? Colors.black
                        : Colors.greenAccent,
                    glow: isDriving && drivingLedOn,
                    glowColor: Colors.greenAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isDriving ? '주행 중' : '주행',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: isDriving ? _finishDriving : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                disabledBackgroundColor: Colors.grey.shade800,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _statusDot(
                    color: isDriving ? Colors.redAccent : Colors.red.shade900,
                    glow: isDriving,
                    glowColor: Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '종료',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusDot({
    required Color color,
    required bool glow,
    required Color glowColor,
  }) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: glow
            ? [BoxShadow(color: glowColor, blurRadius: 8, spreadRadius: 2)]
            : null,
      ),
    );
  }
}

Widget _fareNoticeBox() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.grey.shade900.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade800),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 5),
            Text(
              '요금 적용 기준 안내',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '• 기본요금 4,800원(1.6km) 이후 km당 1,000원으로 계산합니다.\n'
          '• 시속 15km 미만(정차 포함)일 때 30초당 100원이 가산됩니다.\n'
          '• 할증(20%), 시외(30%)가 가산됩니다.\n'
          '• 실제 택시미터기 요금과 다를 수 있습니다.',
          style: TextStyle(
            fontSize: 11,
            height: 1.4,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    ),
  );
}
