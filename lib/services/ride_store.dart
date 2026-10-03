import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 완료된 주행 한 건의 기록.
class RideRecord {
  final DateTime date;
  final double distance; // km
  final int fare; // 원

  const RideRecord({
    required this.date,
    required this.distance,
    required this.fare,
  });

  Map<String, dynamic> toJson() => {
    'date': date.millisecondsSinceEpoch,
    'distance': distance,
    'fare': fare,
  };

  factory RideRecord.fromJson(Map<String, dynamic> json) => RideRecord(
    date: DateTime.fromMillisecondsSinceEpoch(json['date'] as int),
    distance: (json['distance'] as num).toDouble(),
    fare: (json['fare'] as num).toInt(),
  );
}

/// 최근 주행 기록을 휴대폰 저장소에 보관합니다. (최대 10개, 최신 기록이 맨 위)
/// 앱을 완전히 종료했다 켜도 남아 있습니다.
class RideStore {
  RideStore._();

  static const int maxRecords = 10;
  static const String _key = 'ride_records';

  static final List<RideRecord> records = [];

  /// 앱 시작 시 저장된 기록을 불러옵니다.
  static Future<void> load() async {
    records.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;

      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        records.add(RideRecord.fromJson(item as Map<String, dynamic>));
      }
    } catch (e) {
      // 저장된 데이터가 깨져 있으면 기록만 비우고 앱은 정상 실행
      debugPrint('주행 기록 불러오기 실패: $e');
      records.clear();
    }
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }

  /// 새 기록을 맨 위에 추가하고, 10개를 넘으면 가장 오래된 것부터 지웁니다.
  static Future<void> add(RideRecord record) async {
    records.insert(0, record);
    while (records.length > maxRecords) {
      records.removeLast();
    }
    await _save();
  }

  /// 기록 한 건 삭제
  static Future<void> remove(RideRecord record) async {
    records.remove(record);
    await _save();
  }

  /// 기록 전체 삭제
  static Future<void> clear() async {
    records.clear();
    await _save();
  }
}