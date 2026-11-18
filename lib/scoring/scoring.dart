/// KickSafe 점수 계산 모듈 진입점.
///
/// 사용 예:
/// ```dart
/// final detector = EventDetector();
/// final weather = WeatherService(); // lib/services/weather_service.dart
/// final cond = await weather.currentCondition(lat: lat, lon: lon); // 위치 모르면 인자 생략(서울)
/// final calc = ScoreCalculator(
///   context: RideContext(isNight: isNight, weather: cond),
/// );
///
/// bleSensorService.subscribe(device, (reading) {
///   for (final e in detector.addSample(reading)) {
///     final penalty = calc.applyEvent(e);
///     if (penalty > 0) firestore.saveScoreEvent(sessionId, e.label, penalty);
///   }
/// });
///
/// // 세션 종료
/// firestore.endSession(sessionId, calc.score);
/// ```

export 'scoring_rules.dart';
export 'score_calculator.dart';
export 'event_detector.dart';
export 'window_features.dart';
