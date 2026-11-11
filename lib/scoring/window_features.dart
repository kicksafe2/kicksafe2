import 'dart:math';

import '../services/ble_sensor_service.dart' show SensorReading;

/// 1초 윈도우(예: 50Hz → 50개)의 센서값을 통계 피처로 요약.
/// docs/RF_학습데이터_요구사항.csv [3]번 피처 정의와 동일한 항목.
/// 룰 기반 감지(EventDetector)와 RF 입력 양쪽에서 같이 쓴다.
class WindowFeatures {
  final double accMagMean, accMagMax, accMagStd;
  final double axMean, ayMean, azMean;
  final double axStd, ayStd, azStd;
  final double gyroMagMax;
  final double gxStd, gyStd, gzStd;
  final double jerkMax;
  final int count;

  const WindowFeatures({
    required this.accMagMean,
    required this.accMagMax,
    required this.accMagStd,
    required this.axMean,
    required this.ayMean,
    required this.azMean,
    required this.axStd,
    required this.ayStd,
    required this.azStd,
    required this.gyroMagMax,
    required this.gxStd,
    required this.gyStd,
    required this.gzStd,
    required this.jerkMax,
    required this.count,
  });

  /// [samples]가 비어 있으면 null
  static WindowFeatures? compute(List<SensorReading> samples) {
    if (samples.isEmpty) return null;

    final n = samples.length;
    final accMag = samples.map((s) => s.accelMagnitude).toList();
    final ax = samples.map((s) => s.ax).toList();
    final ay = samples.map((s) => s.ay).toList();
    final az = samples.map((s) => s.az).toList();
    final gx = samples.map((s) => s.gx).toList();
    final gy = samples.map((s) => s.gy).toList();
    final gz = samples.map((s) => s.gz).toList();
    final gyroMag = samples
        .map((s) => sqrt(s.gx * s.gx + s.gy * s.gy + s.gz * s.gz))
        .toList();

    double jerkMax = 0;
    for (var i = 1; i < n; i++) {
      final d = (accMag[i] - accMag[i - 1]).abs();
      if (d > jerkMax) jerkMax = d;
    }

    return WindowFeatures(
      accMagMean: _mean(accMag),
      accMagMax: accMag.reduce(max),
      accMagStd: _std(accMag),
      axMean: _mean(ax),
      ayMean: _mean(ay),
      azMean: _mean(az),
      axStd: _std(ax),
      ayStd: _std(ay),
      azStd: _std(az),
      gyroMagMax: gyroMag.reduce(max),
      gxStd: _std(gx),
      gyStd: _std(gy),
      gzStd: _std(gz),
      jerkMax: jerkMax,
      count: n,
    );
  }

  /// RF 모델 입력 순서 (학습 코드와 반드시 동일하게 유지)
  List<double> toVector() => [
        accMagMean, accMagMax, accMagStd,
        axMean, ayMean, azMean,
        axStd, ayStd, azStd,
        gyroMagMax,
        gxStd, gyStd, gzStd,
        jerkMax,
      ];

  static const featureNames = [
    'acc_mag_mean', 'acc_mag_max', 'acc_mag_std',
    'ax_mean', 'ay_mean', 'az_mean',
    'ax_std', 'ay_std', 'az_std',
    'gyro_mag_max',
    'gx_std', 'gy_std', 'gz_std',
    'jerk_max',
  ];

  Map<String, double> toMap() =>
      Map.fromIterables(featureNames, toVector());

  static double _mean(List<double> v) =>
      v.reduce((a, b) => a + b) / v.length;

  static double _std(List<double> v) {
    if (v.length < 2) return 0;
    final m = _mean(v);
    var s = 0.0;
    for (final x in v) {
      s += (x - m) * (x - m);
    }
    return sqrt(s / v.length);
  }
}
