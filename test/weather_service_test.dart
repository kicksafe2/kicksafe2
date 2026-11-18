import 'package:flutter_application_1/scoring/scoring_rules.dart';
import 'package:flutter_application_1/services/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _header =
    '# YYMMDDHHMI STN   WD1    WS1    WDS    WSS   WD10   WS10     TA     RE  RN-15m  RN-60m  RN-12H  RN-DAY     HM     PA     PS     TD';

void main() {
  test('맑음', () {
    final obs = WeatherService.parseMinuteData('''
$_header
202611181300 108  270.0    2.1  280.0    3.5  275.0    2.0    8.3    0.0    0.0    0.0    0.0    0.0   45.0 1012.3 1020.1   -3.2
''', station: 108)!;
    expect(obs.temperature, 8.3);
    expect(obs.condition, WeatherCondition.clear);
  });

  test('비', () {
    final obs = WeatherService.parseMinuteData('''
$_header
202611181300 108  270.0    2.1  280.0    3.5  275.0    2.0    8.3    1.0    0.5    1.0    1.0    1.0   90.0 1012.3 1020.1    6.9
''', station: 108)!;
    expect(obs.condition, WeatherCondition.rain);
  });

  test('눈 (강수 + 기온 1도 이하)', () {
    final obs = WeatherService.parseMinuteData('''
$_header
202611181300 108  270.0    2.1  280.0    3.5  275.0    2.0   -1.5    1.0    0.0    0.0    0.0    0.0   90.0 1012.3 1020.1   -2.0
''', station: 108)!;
    expect(obs.condition, WeatherCondition.snow);
  });

  test('결측값이면 unknown', () {
    final obs = WeatherService.parseMinuteData('''
$_header
202611181300 108  -99.9  -99.9  -99.9  -99.9  -99.9  -99.9  -99.9  -99.9  -99.9  -99.9  -99.9  -99.9  -99.9  -99.9  -99.9  -99.9
''', station: 108)!;
    expect(obs.condition, WeatherCondition.unknown);
  });

  test('데이터 없으면 null', () {
    expect(WeatherService.parseMinuteData('#START7777\n#7777END\n'), isNull);
  });
}
