import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ride_store.dart';
import '../utils/formatters.dart';
import '../widgets/ad_banner.dart';
import '../widgets/horse_led.dart';
import 'ride_complete_page.dart';
import 'ride_history_page.dart';
import 'ranking_page.dart';
import 'settings_page.dart';

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

  Timer? timer;

  static const int baseFare = 4800;

  // 주행 버튼 LED 깜빡임
  bool drivingLedOn = true;
  Timer? ledTimer;

  @override
  void initState() {
    super.initState();

    // ===== 주행 버튼 안의 점(LED) 깜빡이는 속도 조정 지점 =====
    // 아래 500ms 값을 줄이면 더 빠르게, 늘리면 더 느리게 깜빡입니다.
    ledTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;

      if (isDriving) {
        setState(() {
          drivingLedOn = !drivingLedOn;
        });
      }
    });
  }

  void _startDriving() {
    if (isDriving) return;

    setState(() {
      isDriving = true;
      fare = baseFare;
      distance = 0;
      speed = 20;
      drivingLedOn = true;
    });

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        distance += 0.01;
        speed = 20 + ((distance * 10).toInt() % 50);
        _calculateFare();
      });
    });
  }

  void _calculateFare() {
    double calculated = baseFare.toDouble();

    if (distance > 1.6) {
      calculated += (distance - 1.6) * 1000;
    }

    if (surcharge) {
      calculated *= 2;
    }

    if (outsideCity) {
      calculated *= 2;
    }

    fare = calculated.round();
  }

  void _toggleSurcharge() {
    setState(() {
      surcharge = !surcharge;
      _calculateFare();
    });
  }

  void _toggleOutsideCity() {
    setState(() {
      outsideCity = !outsideCity;
      _calculateFare();
    });
  }

  String _today() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}.${two(now.month)}.${two(now.day)}';
  }

  Future<void> _finishDriving() async {
    if (!isDriving) return;

    timer?.cancel();

    // 주행이 끝나는 시점에 기록 저장소에 추가
    RideStore.add(
      RideRecord(
        region: widget.region,
        distance: distance,
        fare: fare,
        date: _today(),
      ),
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideCompletePage(
          region: widget.region,
          distance: distance,
          fare: fare,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {
        isDriving = false;
        distance = 0;
        fare = 0;
        speed = 0;
        surcharge = false;
        outsideCity = false;
        drivingLedOn = true;
      });
    }
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RideHistoryPage()),
    );
  }

  void _openRanking() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RankingPage()),
    );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

                    const SizedBox(height: 15),

                    HorseLed(running: isDriving, speed: speed),

                    const SizedBox(height: 15),

                    _infoDisplay(),

                    const SizedBox(height: 20),

                    _optionButtons(),

                    const SizedBox(height: 12),

                    _mainButtons(),

                    const SizedBox(height: 12),

                    _bottomNavButtons(),
                  ],
                ),
              ),
            ),

            const AdBanner(),
          ],
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
          color: active ? Colors.greenAccent : Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoDisplay() {
    return Row(
      children: [
        Expanded(child: _infoBox('거리', '${distance.toStringAsFixed(2)} km')),
        const SizedBox(width: 10),
        Expanded(child: _infoBox('속도', '$speed km/h')),
      ],
    );
  }

  Widget _infoBox(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _mainButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 60,
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
            height: 60,
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

  Widget _bottomNavButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _openHistory,
              icon: const Icon(Icons.history),
              label: const Text('주행기록', style: TextStyle(fontSize: 15)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _openRanking,
              icon: const Icon(Icons.emoji_events),
              label: const Text('랭킹보기', style: TextStyle(fontSize: 15)),
            ),
          ),
        ),
      ],
    );
  }
}
