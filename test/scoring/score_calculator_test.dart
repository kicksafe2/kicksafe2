import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/scoring/scoring.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 12, 0, 0);

  group('ScoreCalculator 기본 감점', () {
    test('시작 점수는 100', () {
      expect(ScoreCalculator().score, 100);
    });

    test('넘어짐 1회 → 30점 감점', () {
      final c = ScoreCalculator();
      final p = c.applyEvent(DrivingEventType.fallImpact, time: t0);
      expect(p, 30);
      expect(c.score, 70);
    });

    test('급정거 + 급회전 → 10점 감점', () {
      final c = ScoreCalculator();
      c.applyEvent(DrivingEventType.hardBrake, time: t0);
      c.applyEvent(DrivingEventType.sharpTurn, time: t0);
      expect(c.score, 90);
    });

    test('점수는 0 아래로 내려가지 않음', () {
      final c = ScoreCalculator();
      for (var i = 0; i < 10; i++) {
        c.applyEvent(DrivingEventType.fallImpact,
            time: t0.add(Duration(seconds: i * 5)));
      }
      expect(c.score, 0);
    });
  });

  group('배수', () {
    test('야간 1.5배: 과속 10 → 15', () {
      final c = ScoreCalculator(context: const RideContext(isNight: true));
      expect(c.applyEvent(DrivingEventType.speedViolation, time: t0), 15);
    });

    test('비 1.3배: 급가속 5 → 7 (반올림)', () {
      final c = ScoreCalculator(
          context: const RideContext(weather: WeatherCondition.rain));
      expect(c.applyEvent(DrivingEventType.hardAccel, time: t0), 7);
    });

    test('야간 + 눈 = 2.25배: 넘어짐 30 → 68', () {
      final c = ScoreCalculator(
        context: const RideContext(
            isNight: true, weather: WeatherCondition.snow),
      );
      expect(c.currentMultiplier, closeTo(2.25, 1e-9));
      expect(c.applyEvent(DrivingEventType.fallImpact, time: t0), 68);
    });

    test('주행 중 컨텍스트 변경이 이후 이벤트에 반영됨', () {
      final c = ScoreCalculator();
      c.applyEvent(DrivingEventType.hardBrake, time: t0);
      c.context = c.context.copyWith(isNight: true);
      final p = c.applyEvent(DrivingEventType.hardBrake,
          time: t0.add(const Duration(seconds: 10)));
      expect(p, 8); // 5 × 1.5 = 7.5 → 8
    });
  });

  group('쿨다운 / 상한 / 면제', () {
    test('2초 안에 같은 이벤트는 한 번만 감점', () {
      final c = ScoreCalculator();
      c.applyEvent(DrivingEventType.hardBrake, time: t0);
      final p = c.applyEvent(DrivingEventType.hardBrake,
          time: t0.add(const Duration(milliseconds: 500)));
      expect(p, 0);
      expect(c.score, 95);
      expect(c.events.last.skippedReason, 'cooldown');
    });

    test('2초 지나면 다시 감점', () {
      final c = ScoreCalculator();
      c.applyEvent(DrivingEventType.hardBrake, time: t0);
      c.applyEvent(DrivingEventType.hardBrake,
          time: t0.add(const Duration(seconds: 2)));
      expect(c.score, 90);
    });

    test('다른 종류 이벤트는 쿨다운 영향 없음', () {
      final c = ScoreCalculator();
      c.applyEvent(DrivingEventType.hardBrake, time: t0);
      c.applyEvent(DrivingEventType.sharpTurn, time: t0);
      expect(c.score, 90);
    });

    test('급정거 세션 상한 30점', () {
      final c = ScoreCalculator();
      for (var i = 0; i < 10; i++) {
        c.applyEvent(DrivingEventType.hardBrake,
            time: t0.add(Duration(seconds: i * 3)));
      }
      expect(c.score, 70);
      expect(c.penaltyBreakdown[DrivingEventType.hardBrake], 30);
      expect(c.events.last.skippedReason, 'type_cap');
    });

    test('넘어짐은 상한 없음', () {
      final c = ScoreCalculator();
      c.applyEvent(DrivingEventType.fallImpact, time: t0);
      c.applyEvent(DrivingEventType.fallImpact,
          time: t0.add(const Duration(seconds: 5)));
      expect(c.score, 40);
    });

    test('AI 면제 이벤트는 기록만 되고 감점 없음', () {
      final c = ScoreCalculator();
      final p =
          c.applyEvent(DrivingEventType.fallImpact, exempt: true, time: t0);
      expect(p, 0);
      expect(c.score, 100);
      expect(c.events.length, 1);
      expect(c.events.first.exempt, isTrue);
      expect(c.penalizedEvents, isEmpty);
    });

    test('면제 이벤트는 쿨다운을 시작시키지 않음', () {
      final c = ScoreCalculator();
      c.applyEvent(DrivingEventType.fallImpact, exempt: true, time: t0);
      final p = c.applyEvent(DrivingEventType.fallImpact,
          time: t0.add(const Duration(milliseconds: 100)));
      expect(p, 30);
    });
  });

  group('도로 유형', () {
    test('인도 주행 tick → 감점', () {
      final c = ScoreCalculator(
          context: const RideContext(roadType: RoadType.sidewalk));
      expect(c.applyRoadTypeTick(time: t0), 10);
    });

    test('차도/자전거도로 tick → 감점 없음', () {
      final c = ScoreCalculator(
          context: const RideContext(roadType: RoadType.bikeLane));
      expect(c.applyRoadTypeTick(time: t0), 0);
      expect(c.events, isEmpty);
    });
  });

  group('결과', () {
    test('등급 경계', () {
      final c = ScoreCalculator();
      expect(c.grade, 'A');
      c.applyEvent(DrivingEventType.noHelmet, time: t0); // 85
      expect(c.grade, 'B');
      c.applyEvent(DrivingEventType.fallImpact, time: t0); // 55
      expect(c.grade, 'D');
    });

    test('toMap에 Firestore 저장용 필드 포함', () {
      final c = ScoreCalculator();
      c.applyEvent(DrivingEventType.hardBrake, time: t0);
      final m = c.events.first.toMap();
      expect(m['type'], 'hard_brake');
      expect(m['penalty'], 5);
      expect(m['exempt'], false);
    });

    test('reset 후 초기 상태', () {
      final c = ScoreCalculator();
      c.applyEvent(DrivingEventType.fallImpact, time: t0);
      c.reset();
      expect(c.score, 100);
      expect(c.events, isEmpty);
      // 쿨다운도 초기화되어야 함
      expect(c.applyEvent(DrivingEventType.fallImpact, time: t0), 30);
    });

    test('라벨 ↔ enum 왕복', () {
      for (final t in DrivingEventType.values) {
        expect(DrivingEventTypeLabel.fromLabel(t.label), t);
      }
      expect(DrivingEventTypeLabel.fromLabel('nope'), isNull);
    });
  });
}
