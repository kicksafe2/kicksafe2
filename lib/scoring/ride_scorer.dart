import '../services/ble_sensor_service.dart' show SensorReading;
import 'event_detector.dart';
import 'score_calculator.dart';
import 'scoring_rules.dart';

/// 야간 판정(감점 배수 ×1.5 적용). 20시 이후 ~ 06시 이전.
bool isNightTime(DateTime t) => t.hour >= 20 || t.hour < 6;

/// 주행 1회 동안 센서 값을 받아 점수를 계산하는 진행 엔진.
///
/// [EventDetector]는 "샘플 N개 = 1초(50Hz)"를 전제로 하지만, 실제 센서 전송 속도는
/// 펌웨어 설정에 따라 다르다(예: 0.3초 간격 = 약 3Hz). 그래서 샘플 개수가 아니라
/// **시계 기준 [windowDuration]** 으로 윈도우를 묶어 [EventDetector.detectFromWindow]에 넘긴다.
///
/// 순수 Dart(BLE/Firebase 의존 없음)라서 테스트에서 [now]를 넣어 시간을 흉내낼 수 있다.
class RideScorer {
  final EventDetector _detector;
  final ScoreCalculator _calc;
  final Duration windowDuration;

  /// 윈도우에 이 개수보다 샘플이 적으면 판정하지 않는다(연결이 끊겼다 이어진 직후 등).
  final int minSamplesPerWindow;

  final List<SensorReading> _buffer = [];
  DateTime? _windowStart;
  int _readingCount = 0;

  RideScorer({
    DetectorThresholds thresholds = const DetectorThresholds(),
    SensorOrientation orientation = const SensorOrientation(),
    ScoringRules rules = ScoringRules.defaults,
    RideContext context = const RideContext(),
    this.windowDuration = const Duration(seconds: 1),
    this.minSamplesPerWindow = 2,
  })  : _detector = EventDetector(thresholds: thresholds, orientation: orientation),
        _calc = ScoreCalculator(rules: rules, context: context);

  /// 현재 점수 (시작 100점)
  int get score => _calc.score;

  /// 지금까지 받은 센서 샘플 수 (0이면 센서가 연결되지 않았거나 값이 안 들어온 것)
  int get readingCount => _readingCount;

  /// 이벤트 종류별 실제 감점된 횟수
  Map<DrivingEventType, int> get eventCounts {
    final out = <DrivingEventType, int>{};
    for (final e in _calc.penalizedEvents) {
      out[e.type] = (out[e.type] ?? 0) + 1;
    }
    return out;
  }

  /// 이벤트 종류별 감점 합계
  Map<DrivingEventType, int> get penaltyBreakdown => _calc.penaltyBreakdown;

  /// 감점이 반영된 이벤트 전체
  List<ScoredEvent> get penalizedEvents => _calc.penalizedEvents;

  String get grade => _calc.grade;

  /// 주행 중 환경(야간/날씨/도로)이 바뀌면 이후 이벤트부터 반영된다.
  set context(RideContext c) => _calc.context = c;

  /// 센서 샘플 1개를 넣는다. 윈도우가 닫히면 그 안에서 새로 **감점된** 이벤트를 돌려준다.
  List<ScoredEvent> addReading(SensorReading r, {DateTime? now}) {
    final t = now ?? DateTime.now();
    _readingCount++;
    _windowStart ??= t;
    _buffer.add(r);
    if (t.difference(_windowStart!) < windowDuration) return const [];
    return _closeWindow(t);
  }

  /// 아직 닫히지 않은 마지막 윈도우를 마저 판정한다. (주행 종료 직전에 호출)
  List<ScoredEvent> flush({DateTime? now}) => _closeWindow(now ?? DateTime.now());

  /// 점수와 상태를 처음으로 되돌린다.
  void reset({RideContext? context}) {
    _buffer.clear();
    _windowStart = null;
    _readingCount = 0;
    _detector.reset();
    _calc.reset(newContext: context);
  }

  List<ScoredEvent> _closeWindow(DateTime now) {
    final samples = List<SensorReading>.of(_buffer);
    _buffer.clear();
    _windowStart = now;
    if (samples.length < minSamplesPerWindow) return const [];

    final before = _calc.events.length;
    for (final type in _detector.detectFromWindow(samples)) {
      _calc.applyEvent(type, time: now);
    }
    return [
      for (final e in _calc.events.skip(before))
        if (e.appliedPenalty > 0) e,
    ];
  }
}
