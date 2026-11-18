import '../services/ble_sensor_service.dart' show SensorReading;
import 'scoring_rules.dart';
import 'window_features.dart';

/// 룰 기반 감지 임계값. **내일 실주행 테스트 결과를 보고 이 클래스의 기본값만 고치면 된다.**
///
/// 근거: 카르타헤나 킥보드 공개 데이터(UPCT, CC BY 4.0, 폰 센서 100Hz) 분석.
///  - 정상 주행(도로 209초 + 자갈길 106초, 시속 10~20km)과 사고 시험(실내 넘어짐 6폴더, 정면충돌 3폴더)을
///    같은 1초 윈도우로 비교했다. 사고 시험은 매트/러그 위 약 10km/h 라서 실제 사고보다 약하다.
///  - 정상 주행의 1초 윈도우 가속도 최댓값은 중앙값 1.5g(도로)·2.4g(자갈길), 99% 5.4g·7.8g, 최대 12.3g.
///    → 기존 값 2.0g 는 정상 주행 1초의 절반 이상을 "넘어짐"으로 판정한다. (가속도 하나로는 구분 불가)
///  - 넘어짐은 가속도 12~19g + 자이로 크기 240~950°/s, 정상 주행 자이로 최댓값은 최대 약 146°/s.
///    → "충격 AND 회전" 조합이면 정상 주행 오탐 0%(데이터 기준)로 사고만 걸러진다.
///  - 이 감지기를 정상 주행 32분(도로·자갈길)에 그대로 재생한 결과(50Hz):
///      급가속+급정거 0.4g → 분당 1.27건(10분 -64점) / 0.6g → 0.44건 / 0.8g → 0.16건(10분 -8점) / 1.0g → 0.12건
///      급회전 120°/s → 분당 0.19건 / 130°/s → 0.09건 / 140°/s 이상 → 0건
///    → 정상 주행이 10분에 약 10점 이내로만 깎이도록 급가속·급정거 0.8g, 급회전 140°/s 로 정했다.
///    (1초 평균 가속도가 0.8g 바뀌는 건 매우 급한 제동이다. 실제 주행에서 급정거가 한 번도 안 잡히면 0.6g 쪽으로 낮춘다.)
///
/// 한계: 폰 센서 기록이라 우리 MPU6050(핸들 하단)과 장착·진동 특성이 다르다. 그래서 "초기값"이다.
class DetectorThresholds {
  /// 1초 윈도우의 가속도 크기(g) 최댓값이 이 값을 넘고(그리고 [fallGyroDps]도 넘으면) 넘어짐/충돌.
  /// 데이터: 정상 주행 1% 구간이 5g 이상이라 단독 판정은 불가 → 자이로와 AND.
  final double fallImpactG;

  /// 넘어짐/충돌 판정에 같이 필요한 자이로 크기(°/s) 최댓값.
  /// 데이터: 정상 주행 최대 146°/s, 넘어짐 사고 윈도우 대부분 240°/s 이상.
  final double fallGyroDps;

  /// 진행축 가속도 변화(g)가 이 값 이상 증가 → 급가속.
  /// 데이터: 0.4g 는 정상 주행에서 분당 1.3건 오탐, 0.8g 는 분당 0.16건.
  final double hardAccelDeltaG;

  /// 진행축 가속도 변화(g)가 이 값 이상 감소 → 급정거.
  final double hardBrakeDeltaG;

  /// 회전축 자이로(°/s)가 이 값을 넘으면 급회전.
  /// 데이터: 정상 주행 최대 약 143°/s, 140°/s 기준 재생 오탐 0건(32분).
  final double sharpTurnDps;

  const DetectorThresholds({
    this.fallImpactG = 4.0,
    this.fallGyroDps = 150,
    this.hardAccelDeltaG = 0.80,
    this.hardBrakeDeltaG = 0.80,
    this.sharpTurnDps = 140,
  });

  /// 주행 기록에 "이 주행에서 쓴 임계값"을 남길 때 쓴다.
  Map<String, double> toMap() => {
        'fallImpactG': fallImpactG,
        'fallGyroDps': fallGyroDps,
        'hardAccelDeltaG': hardAccelDeltaG,
        'hardBrakeDeltaG': hardBrakeDeltaG,
        'sharpTurnDps': sharpTurnDps,
      };
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
    //    충격(가속도)과 회전(자이로)이 같은 윈도우에 함께 있을 때만 인정한다.
    //    (가속도만으로는 자갈길·연석 통과를 사고로 오인함)
    if (f.accMagMax > thresholds.fallImpactG && f.gyroMagMax > thresholds.fallGyroDps) {
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
