import 'scoring_rules.dart';

/// 점수에 반영된(또는 면제된) 이벤트 1건의 기록
class ScoredEvent {
  final DrivingEventType type;
  final DateTime time;

  /// 실제로 차감된 점수 (면제·쿨다운·상한 걸리면 0)
  final int appliedPenalty;

  /// 배수 적용 전 기본 감점
  final int basePenalty;

  /// 적용된 총 배수 (야간 × 날씨)
  final double multiplier;

  /// AI가 "정상 상황"으로 판정해 면제된 경우 true (예: 방지턱, 의도적 정차)
  final bool exempt;

  /// 쿨다운/상한 때문에 무시된 경우 사유
  final String? skippedReason;

  const ScoredEvent({
    required this.type,
    required this.time,
    required this.appliedPenalty,
    required this.basePenalty,
    required this.multiplier,
    this.exempt = false,
    this.skippedReason,
  });

  Map<String, dynamic> toMap() => {
        'type': type.label,
        'timestamp': time.millisecondsSinceEpoch,
        'penalty': appliedPenalty,
        'basePenalty': basePenalty,
        'multiplier': multiplier,
        'exempt': exempt,
        if (skippedReason != null) 'skipped': skippedReason,
      };
}

/// 세션 1회분의 점수를 관리하는 계산기.
///
/// 순수 Dart — Firebase/BLE 의존 없음. 이벤트를 넣으면 감점을 계산해 돌려주고,
/// 호출 측(세션 컨트롤러)이 그 결과를 Firestore에 저장하면 된다.
class ScoreCalculator {
  final ScoringRules rules;
  RideContext context;

  int _score;
  final List<ScoredEvent> _events = [];
  final Map<DrivingEventType, DateTime> _lastAccepted = {};
  final Map<DrivingEventType, int> _accumulated = {};

  ScoreCalculator({
    this.rules = ScoringRules.defaults,
    this.context = const RideContext(),
  }) : _score = rules.baseScore;

  int get score => _score;
  List<ScoredEvent> get events => List.unmodifiable(_events);

  /// 실제 감점이 반영된 이벤트만
  List<ScoredEvent> get penalizedEvents =>
      _events.where((e) => e.appliedPenalty > 0).toList();

  /// 현재 컨텍스트의 총 배수 (야간 × 날씨)
  double get currentMultiplier {
    final night = context.isNight ? rules.nightMultiplier : 1.0;
    final weather = rules.weatherMultiplier[context.weather] ?? 1.0;
    return night * weather;
  }

  /// 이벤트 1건 반영. 실제 차감된 점수를 돌려준다.
  ///
  /// [exempt]가 true면 (AI가 정상 상황으로 분류) 기록만 남기고 감점하지 않는다.
  /// [time]은 테스트/재생용. 생략하면 현재 시각.
  int applyEvent(
    DrivingEventType type, {
    bool exempt = false,
    DateTime? time,
  }) {
    final now = time ?? DateTime.now();
    final base = rules.basePenalty[type] ?? 0;
    final mult = currentMultiplier;

    // 1) AI 면제
    if (exempt) {
      _events.add(ScoredEvent(
        type: type,
        time: now,
        appliedPenalty: 0,
        basePenalty: base,
        multiplier: mult,
        exempt: true,
      ));
      return 0;
    }

    // 2) 쿨다운 (같은 이벤트 연속 중복 방지)
    final last = _lastAccepted[type];
    if (last != null && now.difference(last) < rules.cooldown) {
      _events.add(ScoredEvent(
        type: type,
        time: now,
        appliedPenalty: 0,
        basePenalty: base,
        multiplier: mult,
        skippedReason: 'cooldown',
      ));
      return 0;
    }

    // 3) 배수 적용 → 정수 반올림
    var penalty = (base * mult).round();

    // 4) 종류별 세션 상한
    final cap = rules.maxPenaltyPerType[type];
    final used = _accumulated[type] ?? 0;
    if (cap != null) {
      final remaining = cap - used;
      if (remaining <= 0) {
        _events.add(ScoredEvent(
          type: type,
          time: now,
          appliedPenalty: 0,
          basePenalty: base,
          multiplier: mult,
          skippedReason: 'type_cap',
        ));
        return 0;
      }
      if (penalty > remaining) penalty = remaining;
    }

    // 5) 최저점 바닥
    if (_score - penalty < rules.minScore) {
      penalty = _score - rules.minScore;
    }

    _score -= penalty;
    _lastAccepted[type] = now;
    _accumulated[type] = used + penalty;
    _events.add(ScoredEvent(
      type: type,
      time: now,
      appliedPenalty: penalty,
      basePenalty: base,
      multiplier: mult,
    ));
    return penalty;
  }

  /// 인도 주행은 "상태"라서 이벤트와 달리 주기적으로 호출된다.
  /// 컨텍스트가 sidewalk일 때만 감점.
  int applyRoadTypeTick({DateTime? time}) {
    if (context.roadType != RoadType.sidewalk) return 0;
    return applyEvent(DrivingEventType.sidewalkRiding, time: time);
  }

  /// 이벤트 종류별 감점 합계 (결과 화면용)
  Map<DrivingEventType, int> get penaltyBreakdown {
    final out = <DrivingEventType, int>{};
    for (final e in _events) {
      if (e.appliedPenalty == 0) continue;
      out[e.type] = (out[e.type] ?? 0) + e.appliedPenalty;
    }
    return out;
  }

  /// 등급 (결과 화면/보상용). 기준은 팀 합의로 조정.
  String get grade {
    if (_score >= 90) return 'A';
    if (_score >= 75) return 'B';
    if (_score >= 60) return 'C';
    return 'D';
  }

  void reset({RideContext? newContext}) {
    _score = rules.baseScore;
    _events.clear();
    _lastAccepted.clear();
    _accumulated.clear();
    if (newContext != null) context = newContext;
  }
}
