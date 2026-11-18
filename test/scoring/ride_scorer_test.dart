import 'package:flutter_test/flutter_test.dart';
import 'package:kicksafe/scoring/scoring.dart';
import 'package:kicksafe/services/ble_sensor_service.dart';

SensorReading r({
  double ax = 0,
  double ay = 0,
  double az = 1,
  double gx = 0,
  double gy = 0,
  double gz = 0,
}) =>
    SensorReading(ax: ax, ay: ay, az: az, gx: gx, gy: gy, gz: gz);

final _t0 = DateTime(2026, 11, 18, 14); // 낮 2시

/// [seconds]초 동안 [hz]Hz 로 같은 값을 계속 넣는다. [at]초 시점의 샘플만 [special]로 바꾼다.
/// 윈도우를 닫는 샘플에서 나온 이벤트를 모아 돌려준다.
List<ScoredEvent> run(
  RideScorer s, {
  required double hz,
  required int seconds,
  SensorReading? base,
  Map<int, SensorReading> special = const {},
  int startSecond = 0,
}) {
  final out = <ScoredEvent>[];
  final n = (hz * seconds).round();
  for (var i = 0; i < n; i++) {
    final t = _t0.add(Duration(milliseconds: ((startSecond + i / hz) * 1000).round()));
    out.addAll(s.addReading(special[i] ?? base ?? r(), now: t));
  }
  return out;
}

void main() {
  group('RideScorer — 시계 기준 1초 윈도우', () {
    test('정상 주행은 50Hz 든 3.3Hz 든 감점 없음', () {
      for (final hz in [50.0, 10.0, 3.3]) {
        final s = RideScorer();
        run(s, hz: hz, seconds: 20);
        expect(s.score, 100, reason: '$hz Hz');
        expect(s.eventCounts, isEmpty);
      }
    });

    test('충격 샘플 1개(5g + 200°/s)가 들어오면 넘어짐 -30점 — 3.3Hz 에서도', () {
      for (final hz in [50.0, 3.3]) {
        final s = RideScorer();
        final mid = (hz * 5).round();
        run(s, hz: hz, seconds: 10, special: {mid: r(ax: 4.9, gx: 200)});
        expect(s.score, 70, reason: '$hz Hz');
        expect(s.eventCounts[DrivingEventType.fallImpact], 1);
      }
    });

    test('충격만(자이로 없음) 은 감점 없음 — 자갈길 오탐 방지', () {
      final s = RideScorer();
      run(s, hz: 50, seconds: 10, special: {250: r(ax: 8.0)});
      expect(s.score, 100);
    });

    test('2초 쿨다운: 연속 윈도우의 같은 이벤트는 한 번만 감점', () {
      final s = RideScorer();
      run(s, hz: 50, seconds: 4, special: {60: r(ax: 4.9, gx: 200), 110: r(ax: 4.9, gx: 200)});
      // 윈도우(1초) 경계가 1초 간격이라 둘째 충격은 쿨다운(2초)에 걸림
      expect(s.eventCounts[DrivingEventType.fallImpact], 1);
      expect(s.score, 70);
    });

    test('급정거: 진행축 평균이 직전 1초보다 1.0g 낮아지면 -5점', () {
      final s = RideScorer();
      run(s, hz: 50, seconds: 3, base: r(ax: 0.5));
      run(s, hz: 50, seconds: 3, base: r(ax: -0.5), startSecond: 3);
      s.flush(now: _t0.add(const Duration(seconds: 7)));
      expect(s.eventCounts[DrivingEventType.hardBrake], 1);
      expect(s.score, 95);
    });

    test('flush 는 닫히지 않은 마지막 윈도우를 판정', () {
      final s = RideScorer();
      // 0.5초치만 넣고 충격 포함 → 아직 윈도우가 안 닫힘
      run(s, hz: 50, seconds: 1, special: {10: r(ax: 4.9, gx: 200)});
      final before = s.score;
      s.flush(now: _t0.add(const Duration(milliseconds: 600)));
      expect(before, lessThanOrEqualTo(100));
      expect(s.score, 70);
    });

    test('샘플이 너무 적은 윈도우는 판정하지 않음', () {
      final s = RideScorer(minSamplesPerWindow: 2);
      s.addReading(r(ax: 4.9, gx: 200), now: _t0);
      expect(s.flush(now: _t0.add(const Duration(seconds: 2))), isEmpty);
      expect(s.score, 100);
    });

    test('야간(21시)은 감점 ×1.5: 넘어짐 30 → 45', () {
      final s = RideScorer(context: const RideContext(isNight: true));
      run(s, hz: 50, seconds: 4, special: {60: r(ax: 4.9, gx: 200)});
      expect(s.score, 55);
    });

    test('isNightTime 경계', () {
      expect(isNightTime(DateTime(2026, 1, 1, 19, 59)), isFalse);
      expect(isNightTime(DateTime(2026, 1, 1, 20, 0)), isTrue);
      expect(isNightTime(DateTime(2026, 1, 1, 5, 59)), isTrue);
      expect(isNightTime(DateTime(2026, 1, 1, 6, 0)), isFalse);
    });

    test('readingCount 와 reset', () {
      final s = RideScorer();
      run(s, hz: 10, seconds: 3, special: {5: r(ax: 4.9, gx: 200)});
      expect(s.readingCount, 30);
      s.reset();
      expect(s.readingCount, 0);
      expect(s.score, 100);
      expect(s.penalizedEvents, isEmpty);
    });
  });
}
