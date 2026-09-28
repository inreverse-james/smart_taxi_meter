/// 완료된 주행 한 건의 기록.
class RideRecord {
  final String region;
  final double distance;
  final int fare;
  final String date;

  RideRecord({
    required this.region,
    required this.distance,
    required this.fare,
    required this.date,
  });
}

/// 앱이 실행되는 동안 주행 기록을 메모리에 보관합니다.
/// 앱을 완전히 종료하면 기록이 사라집니다.
/// 재실행 후에도 남기려면 로컬 DB나 Firestore 같은 영구 저장소가 필요합니다.
class RideStore {
  RideStore._();

  static final List<RideRecord> records = [];

  static void add(RideRecord record) {
    records.insert(0, record); // 최신 기록이 위로 오도록
  }
}
