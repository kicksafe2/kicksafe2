import '../scoring/scoring.dart' show DrivingEventType;

/// 위험 이벤트의 화면 표시용 한국어 이름.
extension DrivingEventTypeKo on DrivingEventType {
  String get ko => switch (this) {
        DrivingEventType.hardAccel => '급가속',
        DrivingEventType.hardBrake => '급정거',
        DrivingEventType.sharpTurn => '급회전',
        DrivingEventType.fallImpact => '넘어짐/충돌',
        DrivingEventType.speedViolation => '과속',
        DrivingEventType.noHelmet => '헬멧 미착용',
        DrivingEventType.sidewalkRiding => '인도 주행',
      };
}
