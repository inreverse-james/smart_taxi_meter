/// 택시 종류
enum TaxiType { standard, premium } // standard: 중형택시, premium: 모범택시

/// 한 주행의 요금 누적 상태 (중형/모범 각각 따로 하나씩 가집니다)
///
/// 요금은 "지금 시간대로 전체를 다시 계산"하지 않고,
/// 거리 단위(예: 131m)를 하나 넘을 때마다 "그 순간의 시간대/시외 설정"으로 요금을 쌓아갑니다.
/// 그래서 할증 시간대에 들어간 뒤의 요금만 할증되고, 벗어나면 다시 일반 요금으로 쌓입니다.
class FareState {
  double meters; // 요금에 반영된 거리(m). 느린 시간은 거리로 환산해서 포함
  int units; // 이미 요금으로 환산된 단위 수
  final int baseFare; // 탑승을 시작한 시점의 시간대 기준 기본요금
  int variableWon; // 단위별로 쌓인 거리/시간 요금 (그 순간의 시간대 요금표 적용)
  double outsideWon; // 시외를 켜 둔 동안 쌓인 시외 할증

  FareState({
    required this.baseFare,
    this.meters = 0.0,
    this.units = 0,
    this.variableWon = 0,
    this.outsideWon = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'meters': meters,
    'units': units,
    'base': baseFare,
    'variable': variableWon,
    'outside': outsideWon,
  };

  factory FareState.fromJson(Map<String, dynamic> j) => FareState(
    baseFare: (j['base'] as num).toInt(),
    meters: (j['meters'] as num).toDouble(),
    units: (j['units'] as num).toInt(),
    variableWon: (j['variable'] as num).toInt(),
    outsideWon: (j['outside'] as num).toDouble(),
  );
}

/// 서울 택시 요금 계산 (서울시 공식 요금 체계 기준)
///
///  - 기본요금: 기본거리까지 고정 (탑승 시작 시점의 시간대 기준)
///  - 이후 "거리요금": 일정 거리(unitMeters)를 넘을 때마다 일정 금액(unitWon)이 올라감
///  - "시간요금": 느리게 가거나 정차한 시간을 거리로 환산해서 같은 방식으로 반영
///    (중형: 시간·거리 부분 동시병산 / 모범: 시간·거리 상호병산)
///  - 심야 할증: 단위를 넘는 그 순간의 시간대에 따라 자동 적용 (공식 심야 요금표 사용)
///  - 시외 할증: 시외를 켜 둔 동안 넘은 단위마다 낮 요금의 20%를 더함 (심야와 곱하지 않고 더함)
class FareCalculator {
  FareCalculator._();

  // ============================================================
  // ▼▼▼ 요금표 (요금이 바뀌면 여기 숫자만 고치면 됩니다) ▼▼▼
  static const _Rule _standard = _Rule(
    dayBaseFare: 4800, // 기본요금(원)
    baseMeters: 1600, // 기본거리(m)
    unitMeters: 131, // 이 거리(m)마다
    dayUnitWon: 100, // 이 금액(원)이 올라감
    unitSeconds: 30, // 느릴 때는 이 시간(초)마다 같은 금액이 올라감
    slowKmh: 15.72, // 이 속도(km/h) 미만이면 '느린 상태'
    night20BaseFare: 5800, // 심야 20%(22~23시, 02~04시) 기본요금
    night20UnitWon: 120, //                           올라가는 금액
    night40BaseFare: 6700, // 심야 40%(23~02시) 기본요금
    night40UnitWon: 140, //                    올라가는 금액
  );

  static const _Rule _premium = _Rule(
    dayBaseFare: 7000,
    baseMeters: 3000,
    unitMeters: 151,
    dayUnitWon: 200,
    unitSeconds: 36,
    slowKmh: 15.10,
    night20BaseFare: 8400, // 모범은 심야(22~04시) 한 가지(20%)만 있음
    night20UnitWon: 240,
    night40BaseFare: 8400,
    night40UnitWon: 240,
  );

  /// 시외 할증 비율 (낮 요금에 더해짐)
  static const double outsideRate = 0.2;
  // ▲▲▲ 요금표 끝 ▲▲▲
  // ============================================================

  static _Rule _rule(TaxiType type) =>
      type == TaxiType.premium ? _premium : _standard;

  /// 지금 시각의 심야 할증 비율 (0, 0.2, 0.4)
  static double nightRate(TaxiType type, DateTime t) {
    final h = t.hour;
    if (type == TaxiType.premium) {
      // 모범: 22시 ~ 04시 20%
      return (h >= 22 || h < 4) ? 0.2 : 0.0;
    }
    // 중형: 23시 ~ 02시 40%, 22~23시와 02~04시 20%
    if (h == 23 || h < 2) return 0.4;
    if (h == 22 || (h >= 2 && h < 4)) return 0.2;
    return 0.0;
  }

  /// 이 속도(km/h)가 '느린 상태'인지 (시간요금이 반영되는 상태)
  static bool isSlow(TaxiType type, double kmh) => kmh < _rule(type).slowKmh;

  /// 느린 상태에서 1초가 거리 몇 m로 환산되는지
  static double slowMetersPerSecond(TaxiType type) {
    final r = _rule(type);
    return r.unitMeters / r.unitSeconds;
  }

  /// 탑승을 시작할 때 요금 상태를 만듭니다. (기본요금은 이 시점의 시간대 기준)
  static FareState start(TaxiType type, DateTime now) {
    final r = _rule(type);
    final night = nightRate(type, now);
    final int base = night > 0.3
        ? r.night40BaseFare
        : (night > 0 ? r.night20BaseFare : r.dayBaseFare);
    return FareState(baseFare: base);
  }

  /// 요금에 반영할 거리(m)를 더하고, 새로 넘은 단위만큼 "지금 시간대/시외 설정"으로 요금을 쌓습니다.
  static void addMeters(
    TaxiType type,
    FareState state,
    double meters,
    bool outside,
    DateTime now,
  ) {
    if (meters <= 0) return;
    final r = _rule(type);

    state.meters += meters;

    final extra = state.meters - r.baseMeters;
    final int totalUnits = extra > 0 ? (extra / r.unitMeters).floor() : 0;
    if (totalUnits <= state.units) return;

    final int newUnits = totalUnits - state.units;

    // 지금 시간대의 단위 요금
    final night = nightRate(type, now);
    final int unitWon = night > 0.3
        ? r.night40UnitWon
        : (night > 0 ? r.night20UnitWon : r.dayUnitWon);
    state.variableWon += newUnits * unitWon;

    // 시외 할증은 낮 요금 단위의 20%를 '더함' (곱하지 않음)
    if (outside) {
      state.outsideWon += newUnits * r.dayUnitWon * outsideRate;
    }

    state.units = totalUnits;
  }

  /// 지금까지 쌓인 최종 요금 (십원 단위 반올림)
  static int fare(FareState state) {
    final total = state.baseFare + state.variableWon + state.outsideWon;
    return (total / 10).round() * 10;
  }
}

class _Rule {
  final int dayBaseFare;
  final double baseMeters;
  final double unitMeters;
  final int dayUnitWon;
  final int unitSeconds;
  final double slowKmh;
  final int night20BaseFare;
  final int night20UnitWon;
  final int night40BaseFare;
  final int night40UnitWon;

  const _Rule({
    required this.dayBaseFare,
    required this.baseMeters,
    required this.unitMeters,
    required this.dayUnitWon,
    required this.unitSeconds,
    required this.slowKmh,
    required this.night20BaseFare,
    required this.night20UnitWon,
    required this.night40BaseFare,
    required this.night40UnitWon,
  });
}