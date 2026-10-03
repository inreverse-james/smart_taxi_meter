import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'fare_calculator.dart';

/// 진행 중인 주행 한 건의 정보.
class DriveSession {
  final String region;
  final DateTime startTime;
  final bool outsideCity;
  final bool premium; // 모범택시 요금 적용 여부
  final double distance; // 지금까지 주행한 거리(km)
  final FareState stdState; // 중형 요금 누적 상태
  final FareState prmState; // 모범 요금 누적 상태

  const DriveSession({
    required this.region,
    required this.startTime,
    required this.outsideCity,
    required this.premium,
    required this.stdState,
    required this.prmState,
    this.distance = 0.0,
  });
}

/// 진행 중인 주행을 휴대폰 저장소에 보관합니다.
/// 앱이 백그라운드에서 종료되거나 다시 실행돼도 주행을 이어갈 수 있게 합니다.
class DriveStore {
  DriveStore._();

  /// 현재 진행 중인 주행 (없으면 null)
  static DriveSession? active;

  static const String _kRegion = 'drive_region';
  static const String _kStart = 'drive_start_ms';
  static const String _kOutside = 'drive_outside';
  static const String _kPremium = 'drive_premium';
  static const String _kDistance = 'drive_distance';
  static const String _kFareStd = 'drive_fare_state_std';
  static const String _kFarePrm = 'drive_fare_state_prm';

  // 저장된 요금 상태를 불러옵니다. 없거나 깨져 있으면 주행 거리로 다시 만듭니다.
  static FareState _loadFare(
    SharedPreferences prefs,
    String key,
    TaxiType type,
    DateTime start,
    double distanceKm,
  ) {
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        return FareState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // 아래에서 다시 만듦
      }
    }
    final state = FareCalculator.start(type, start);
    FareCalculator.addMeters(type, state, distanceKm * 1000, false, start);
    return state;
  }

  /// 앱 시작 시 저장된 주행이 있는지 불러옵니다.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final startMs = prefs.getInt(_kStart);

    if (startMs == null) {
      active = null;
      return;
    }

    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final distance = prefs.getDouble(_kDistance) ?? 0.0;

    active = DriveSession(
      region: prefs.getString(_kRegion) ?? '서울',
      startTime: start,
      outsideCity: prefs.getBool(_kOutside) ?? false,
      premium: prefs.getBool(_kPremium) ?? false,
      distance: distance,
      stdState: _loadFare(prefs, _kFareStd, TaxiType.standard, start, distance),
      prmState: _loadFare(prefs, _kFarePrm, TaxiType.premium, start, distance),
    );
  }

  /// 주행 시작 또는 옵션(시외/모범) 변경 시 저장합니다.
  static Future<void> save(DriveSession session) async {
    active = session;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRegion, session.region);
    await prefs.setInt(_kStart, session.startTime.millisecondsSinceEpoch);
    await prefs.setBool(_kOutside, session.outsideCity);
    await prefs.setBool(_kPremium, session.premium);
    await prefs.setDouble(_kDistance, session.distance);
    await prefs.setString(_kFareStd, jsonEncode(session.stdState.toJson()));
    await prefs.setString(_kFarePrm, jsonEncode(session.prmState.toJson()));
  }

  /// 주행이 끝나면 저장된 내용을 지웁니다.
  static Future<void> clear() async {
    active = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRegion);
    await prefs.remove(_kStart);
    await prefs.remove(_kOutside);
    await prefs.remove(_kPremium);
    await prefs.remove(_kDistance);
    await prefs.remove(_kFareStd);
    await prefs.remove(_kFarePrm);
  }
}