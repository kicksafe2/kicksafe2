import '../services/ble_sensor_service.dart' show SensorReading;
import 'scoring_rules.dart';
import 'window_features.dart';

/// 룰 기반 감지 임계값. 실제 수집 데이터 보고 조정.
class DetectorThresholds {
  /// 가속도 크기(g)가 이 값을 넘으면 넘어짐/충돌
  final double fallImpactG;

  /// 진행축 가속도 변화(g)가 이 값 이상 증가 → 급가속
  final double hardAccelDeltaG;

  /// 진행축 가속도 변화(g)가 이 값 이상 감소 → 급정거
  final double hardBrakeDeltaG;

  /// 회전축 자이로(°/s)가 이 값을 넘으면 급회전
  final double sharpTurnDps;

  const DetectorThresholds({
    this.fallImpactG = 2.0, // CSV 요구사항 문서 기준 (>2g)
    this.hardAccelDeltaG = 0.35,
    this.hardBrakeDeltaG = 0.35,
    this.sharpTurnDps = 120,
  });
}

/// 센서 장착 방향. 핸들 하단에 고정한다는 전제로 어느 축이 진행/회전축인지 지정.
/// 실제 장착 후 평지 주행 로그 보고 바꾸면 됨.
class SensorOrientation {
  /// 진행 방향 가속도를 읽을 함수 (기본: x축)
  final double Function(SensorReading) forward;

  /// 좌우 회전(yaw) 각속도를 읽을 함수 (기본: z축)
  final double Function(SensorReading) yaw;

  const SensorOrientation({
    this.forward = _ax,
    this.yaw = _gz,
  });

  static double _ax(SensorReading r) => r.ax;
  static double _gz(SensorReading r) => r.gz;
}

/// 센서 스트림을 1초 윈도우로 묶어 위험 이벤트를 찾아낸다.
///
/// RF 모델이 준비되기 전까지 쓰는 룰 기반 감지기이며,
/// 모델이 들어와도 `WindowFeatures`를 그대로 입력으로 쓸 수 있도록 구조를 맞춰둠.
class EventDetector {
  final DetectorThresholds thresholds;
  final SensorOrientation orientation;
  final int windowSize;

  final List<SensorReading> _window = [];

  /// 직전 윈도우의 진행축 평균 (급가속/급정거 비교 기준)
  double? _prevForwardMean;

  EventDetector({
    this.thresholds = const DetectorThresholds(),
    this.orientation = const SensorOrientation(),
    this.windowSize = 50, // 50Hz × 1초
  });

  /// 샘플 1개 추가. 윈도우가 꽉 찼을 때만 감지 결과를 돌려주고, 아니면 빈 리스트.
  List<DrivingEventType> addSample(SensorReading r) {
    _window.add(r);
    if (_window.length < windowSize) return const [];

    final events = detectFromWindow(_window);
    _window.clear();
    return events;
  }

  /// 윈도우 1개를 평가 (테스트/재생용으로도 직접 호출 가능)
  List<DrivingEventType> detectFromWindow(List<SensorReading> samples) {
    final f = WindowFeatures.compute(samples);
    if (f == null) return const [];

    final events = <DrivingEventType>[];

    // 1) 넘어짐/충돌: 가장 우선. 잡히면 급가속/급정거는 중복이므로 생략.
    if (f.accMagMax > thresholds.fallImpactG) {
      events.add(DrivingEventType.fallImpact);
    } else {
      // 2) 급가속 / 급정거: 직전 윈도우 대비 진행축 평균 변화
      final fwd = samples.map(orientation.forward).toList();
      final fwdMean = fwd.reduce((a, b) => a + b) / fwd.length;
      final prev = _prevForwardMean;
      if (prev != null) {
        final delta = fwdMean - prev;
        if (delta >= thresholds.hardAccelDeltaG) {
          events.add(DrivingEventType.hardAccel);
        } else if (delta <= -thresholds.hardBrakeDeltaG) {
          events.add(DrivingEventType.hardBrake);
        }
      }
      _prevForwardMean = fwdMean;
    }

    // 3) 급회전: 회전축 각속도 최댓값
    final yawMax = samples
        .map((s) => orientation.yaw(s).abs())
        .reduce((a, b) => a > b ? a : b);
    if (yawMax > thresholds.sharpTurnDps) {
      events.add(DrivingEventType.sharpTurn);
    }

    return events;
  }

  void reset() {
    _window.clear();
    _prevForwardMean = null;
  }
}
