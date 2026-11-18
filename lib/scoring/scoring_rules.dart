/// KickSafe 점수 계산 규칙 정의.
///
/// 기본 100점에서 위험 이벤트마다 감점하는 구조.
/// 숫자는 전부 여기서만 바꾸면 되도록 한 곳에 모아둠.
/// (팀 합의로 조정 → 이 파일만 수정)

/// 주행 중 발생하는 위험 이벤트 종류.
/// RF 모델 클래스(hard_accel / hard_brake / sharp_turn / fall_impact)와 1:1 대응되는
/// 항목 + 센서 외 요소(과속·헬멧·인도주행).
enum DrivingEventType {
  hardAccel, // 급가속
  hardBrake, // 급정거
  sharpTurn, // 급회전
  fallImpact, // 넘어짐·충돌
  speedViolation, // 과속
  noHelmet, // 헬멧 미착용
  sidewalkRiding, // 인도 주행 (도로 유형 패널티)
}

/// RF 모델/Firestore 문자열 라벨 ↔ enum 변환
extension DrivingEventTypeLabel on DrivingEventType {
  String get label {
    switch (this) {
      case DrivingEventType.hardAccel:
        return 'hard_accel';
      case DrivingEventType.hardBrake:
        return 'hard_brake';
      case DrivingEventType.sharpTurn:
        return 'sharp_turn';
      case DrivingEventType.fallImpact:
        return 'fall_impact';
      case DrivingEventType.speedViolation:
        return 'speed_violation';
      case DrivingEventType.noHelmet:
        return 'no_helmet';
      case DrivingEventType.sidewalkRiding:
        return 'sidewalk_riding';
    }
  }

  static DrivingEventType? fromLabel(String label) {
    for (final t in DrivingEventType.values) {
      if (t.label == label) return t;
    }
    return null;
  }
}

enum RoadType { road, bikeLane, sidewalk, unknown }

enum WeatherCondition { clear, rain, snow, unknown }

/// 주행 세션의 환경 정보. 감점 배수를 결정한다.
class RideContext {
  final bool isNight;
  final WeatherCondition weather;
  final RoadType roadType;

  const RideContext({
    this.isNight = false,
    this.weather = WeatherCondition.clear,
    this.roadType = RoadType.road,
  });

  RideContext copyWith({
    bool? isNight,
    WeatherCondition? weather,
    RoadType? roadType,
  }) =>
      RideContext(
        isNight: isNight ?? this.isNight,
        weather: weather ?? this.weather,
        roadType: roadType ?? this.roadType,
      );
}

/// 감점 규칙 (조정 가능한 값 모음)
class ScoringRules {
  final int baseScore;
  final int minScore;

  /// 이벤트별 기본 감점
  final Map<DrivingEventType, int> basePenalty;

  /// 야간 배수
  final double nightMultiplier;

  /// 날씨 배수
  final Map<WeatherCondition, double> weatherMultiplier;

  /// 같은 종류 이벤트가 연속으로 잡혔을 때 중복 감점을 막는 최소 간격
  final Duration cooldown;

  /// 이벤트 종류별 세션당 최대 감점(과도한 누적 방지). null이면 제한 없음.
  final Map<DrivingEventType, int> maxPenaltyPerType;

  const ScoringRules({
    this.baseScore = 100,
    this.minScore = 0,
    this.basePenalty = const {
      DrivingEventType.hardAccel: 5,
      DrivingEventType.hardBrake: 5,
      DrivingEventType.sharpTurn: 5,
      DrivingEventType.fallImpact: 30,
      DrivingEventType.speedViolation: 10,
      DrivingEventType.noHelmet: 15,
      DrivingEventType.sidewalkRiding: 10,
    },
    this.nightMultiplier = 1.5,
    this.weatherMultiplier = const {
      WeatherCondition.clear: 1.0,
      WeatherCondition.rain: 1.3,
      WeatherCondition.snow: 1.5,
      WeatherCondition.unknown: 1.0,
    },
    this.cooldown = const Duration(seconds: 2),
    this.maxPenaltyPerType = const {
      DrivingEventType.hardAccel: 30,
      DrivingEventType.hardBrake: 30,
      DrivingEventType.sharpTurn: 30,
      DrivingEventType.speedViolation: 40,
    },
  });

  static const ScoringRules defaults = ScoringRules();
}
