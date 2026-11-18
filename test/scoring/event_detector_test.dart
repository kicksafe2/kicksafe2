import 'package:flutter_test/flutter_test.dart';
import 'package:kicksafe/scoring/scoring.dart';
import 'package:kicksafe/services/ble_sensor_service.dart';

/// 테스트용 샘플 생성기
SensorReading r({
  double ax = 0,
  double ay = 0,
  double az = 1, // 평지 정지: z축에 중력 1g
  double gx = 0,
  double gy = 0,
  double gz = 0,
}) =>
    SensorReading(ax: ax, ay: ay, az: az, gx: gx, gy: gy, gz: gz);

List<SensorReading> steady(int n, {double ax = 0}) =>
    List.generate(n, (_) => r(ax: ax));

void main() {
  group('WindowFeatures', () {
    test('빈 윈도우 → null', () {
      expect(WindowFeatures.compute([]), isNull);
    });

    test('정지 상태: acc_mag ≈ 1g, std 0', () {
      final f = WindowFeatures.compute(steady(50))!;
      expect(f.accMagMean, closeTo(1.0, 1e-9));
      expect(f.accMagMax, closeTo(1.0, 1e-9));
      expect(f.accMagStd, closeTo(0, 1e-9));
      expect(f.gyroMagMax, 0);
      expect(f.count, 50);
    });

    test('피처 벡터 길이와 이름 개수 일치', () {
      final f = WindowFeatures.compute(steady(10))!;
      expect(f.toVector().length, WindowFeatures.featureNames.length);
      expect(f.toMap().keys, containsAll(WindowFeatures.featureNames));
    });

    test('jerk_max는 연속 샘플 간 최대 변화', () {
      final f = WindowFeatures.compute([
        r(az: 1.0),
        r(az: 1.0),
        r(az: 2.5), // 여기서 +1.5
        r(az: 2.0),
      ])!;
      expect(f.jerkMax, closeTo(1.5, 1e-9));
    });
  });

  group('EventDetector', () {
    test('윈도우가 찰 때까지는 아무것도 반환하지 않음', () {
      final d = EventDetector(windowSize: 5);
      for (var i = 0; i < 4; i++) {
        expect(d.addSample(r()), isEmpty);
      }
    });

    test('정상 주행 → 이벤트 없음', () {
      final d = EventDetector();
      expect(d.detectFromWindow(steady(50)), isEmpty);
      expect(d.detectFromWindow(steady(50)), isEmpty);
    });

    test('강한 충격(5g) + 큰 회전(200°/s) → fall_impact', () {
      final d = EventDetector();
      final w = steady(50);
      w[25] = r(ax: 4.9, az: 1.0, gx: 200); // |a| ≈ 5g, 자이로 200°/s
      expect(d.detectFromWindow(w), [DrivingEventType.fallImpact]);
    });

    test('충격만 있고 회전이 없으면 넘어짐 아님 (자갈길·연석 통과 오탐 방지)', () {
      final d = EventDetector();
      final w = steady(50);
      w[25] = r(ax: 6.0, az: 1.0); // 6g 충격이지만 자이로 0
      expect(d.detectFromWindow(w), isEmpty);
    });

    test('회전만 크고 충격이 약하면 넘어짐 아님', () {
      final d = EventDetector();
      final w = steady(50);
      w[25] = r(ax: 1.5, gx: 300); // 자이로 크기는 크지만 |a| ≈ 1.8g
      expect(d.detectFromWindow(w), isEmpty);
    });

    test('진행축 +0.9g 상승 → hard_accel', () {
      final d = EventDetector();
      d.detectFromWindow(steady(50, ax: 0.0));
      expect(d.detectFromWindow(steady(50, ax: 0.9)),
          [DrivingEventType.hardAccel]);
    });

    test('진행축 -0.9g 하강 → hard_brake', () {
      final d = EventDetector();
      d.detectFromWindow(steady(50, ax: 0.5));
      expect(d.detectFromWindow(steady(50, ax: -0.4)),
          [DrivingEventType.hardBrake]);
    });

    test('완만한 변화(0.2g, 0.55g)는 급가속 아님', () {
      final d = EventDetector();
      d.detectFromWindow(steady(50, ax: 0.0));
      expect(d.detectFromWindow(steady(50, ax: 0.2)), isEmpty);
      expect(d.detectFromWindow(steady(50, ax: 0.75)), isEmpty); // 직전 대비 +0.55g
    });

    test('yaw 150°/s → sharp_turn (임계 140°/s)', () {
      final d = EventDetector();
      final w = steady(50);
      w[10] = r(gz: -150);
      expect(d.detectFromWindow(w), [DrivingEventType.sharpTurn]);
    });

    test('충격 + 급회전 동시 → 둘 다 (급가속은 억제)', () {
      final d = EventDetector();
      d.detectFromWindow(steady(50, ax: 0.0));
      final w = steady(50, ax: 1.0);
      w[20] = r(ax: 5.0, gz: 200); // 5g 충격 + 200°/s 회전
      final out = d.detectFromWindow(w);
      expect(out, contains(DrivingEventType.fallImpact));
      expect(out, contains(DrivingEventType.sharpTurn));
      expect(out, isNot(contains(DrivingEventType.hardAccel)));
    });

    test('임계값 커스터마이즈', () {
      final w = steady(50);
      w[0] = r(az: 3.5, gx: 200); // 3.5g 충격 + 200°/s
      // 기본값(4g)에서는 넘어짐이 아니지만, 3g 로 낮추면 넘어짐
      expect(EventDetector().detectFromWindow(w), isEmpty);
      final custom = EventDetector(
          thresholds: const DetectorThresholds(fallImpactG: 3.0));
      expect(custom.detectFromWindow(w), [DrivingEventType.fallImpact]);
    });

    test('장착 방향 바꾸면 진행축이 바뀜 (y축 진행)', () {
      final d = EventDetector(
        orientation: SensorOrientation(forward: (s) => s.ay, yaw: (s) => s.gz),
      );
      d.detectFromWindow(List.generate(50, (_) => r(ay: 0)));
      expect(d.detectFromWindow(List.generate(50, (_) => r(ay: 0.9))),
          [DrivingEventType.hardAccel]);
    });

    test('addSample 스트림 흐름: 50개마다 평가', () {
      final d = EventDetector(windowSize: 50);
      List<DrivingEventType> last = [];
      for (var i = 0; i < 100; i++) {
        final s = i == 70 ? r(az: 5.0, gx: 200) : r();
        final out = d.addSample(s);
        if (out.isNotEmpty) last = out;
      }
      expect(last, [DrivingEventType.fallImpact]);
    });
  });

  group('감지기 → 계산기 통합', () {
    test('넘어짐 1회 + 급정거 1회 세션 → 65점', () {
      final d = EventDetector();
      final c = ScoreCalculator();
      var t = DateTime(2026, 1, 1);

      void feed(List<SensorReading> w) {
        for (final e in d.detectFromWindow(w)) {
          c.applyEvent(e, time: t);
        }
        t = t.add(const Duration(seconds: 1));
      }

      feed(steady(50, ax: 0.5)); // 기준
      feed(steady(50, ax: -0.5)); // 급정거 -5 (Δ1.0g)
      feed(steady(50, ax: -0.5));
      final crash = steady(50, ax: -0.5);
      crash[5] = r(ax: 5.0, gx: 200); // 5g 충격 + 회전
      feed(crash); // 넘어짐 -30
      feed(steady(50, ax: -0.5));

      expect(c.score, 65);
      expect(c.penaltyBreakdown, {
        DrivingEventType.hardBrake: 5,
        DrivingEventType.fallImpact: 30,
      });
    });
  });
}
