import 'package:shared_preferences/shared_preferences.dart';

/// 진행 중인 주행 한 건의 정보.
class DriveSession {
  final String region;
  final DateTime startTime;
  final bool surcharge;
  final bool outsideCity;
  final double distance; // 지금까지 주행한 거리(km)
  final String email;

  const DriveSession({
    required this.region,
    required this.startTime,
    required this.surcharge,
    required this.outsideCity,
    this.distance = 0.0,
    required this.email,
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
  static const String _kSurcharge = 'drive_surcharge';
  static const String _kOutside = 'drive_outside';
  static const String _kDistance = 'drive_distance';
  static const String _kEmail = 'drive_email';

  /// 앱 시작 시 저장된 주행이 있는지 불러옵니다.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final startMs = prefs.getInt(_kStart);

    if (startMs == null) {
      active = null;
      return;
    }

    active = DriveSession(
      region: prefs.getString(_kRegion) ?? '서울',
      startTime: DateTime.fromMillisecondsSinceEpoch(startMs),
      surcharge: prefs.getBool(_kSurcharge) ?? false,
      outsideCity: prefs.getBool(_kOutside) ?? false,
      distance: prefs.getDouble(_kDistance) ?? 0.0,
      email: prefs.getString(_kEmail) ?? '게스트',
    );
  }

  /// 주행 시작 또는 옵션(할증/시외) 변경 시 저장합니다.
  static Future<void> save(DriveSession session) async {
    active = session;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRegion, session.region);
    await prefs.setInt(_kStart, session.startTime.millisecondsSinceEpoch);
    await prefs.setBool(_kSurcharge, session.surcharge);
    await prefs.setBool(_kOutside, session.outsideCity);
    await prefs.setDouble(_kDistance, session.distance);
    await prefs.setString(_kEmail, session.email);
  }

  /// 주행이 끝나면 저장된 내용을 지웁니다.
  static Future<void> clear() async {
    active = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRegion);
    await prefs.remove(_kStart);
    await prefs.remove(_kSurcharge);
    await prefs.remove(_kOutside);
    await prefs.remove(_kDistance);
    await prefs.remove(_kEmail);
  }
}