import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../scoring/scoring_rules.dart';

/// 기상청 API허브 AWS 매분자료(nph-aws2_min) 1건.
class WeatherObservation {
  final int station;
  final DateTime observedAt; // KST 벽시계 시각
  final double? temperature; // TA (°C)
  final bool? precipitationDetected; // RE (강수감지 0/1)
  final double? rain15m; // RN-15m (mm)
  final double? windSpeed; // WS10 (m/s, 10분 평균)

  const WeatherObservation({
    required this.station,
    required this.observedAt,
    this.temperature,
    this.precipitationDetected,
    this.rain15m,
    this.windSpeed,
  });

  /// 점수 계산용 날씨 분류.
  /// 강수 감지(RE=1) 또는 15분 강수량 > 0 이면 강수, 기온 1°C 이하면 눈으로 본다.
  WeatherCondition get condition {
    if (precipitationDetected == null && rain15m == null) {
      return WeatherCondition.unknown;
    }
    final wet = (precipitationDetected ?? false) || (rain15m ?? 0) > 0;
    if (!wet) return WeatherCondition.clear;
    final t = temperature;
    if (t != null && t <= 1.0) return WeatherCondition.snow;
    return WeatherCondition.rain;
  }

  Map<String, dynamic> toMap() => {
        'station': station,
        'observedAt': observedAt.toIso8601String(),
        'temperature': temperature,
        'precipitationDetected': precipitationDetected,
        'rain15m': rain15m,
        'windSpeed': windSpeed,
        'condition': condition.name,
      };

  @override
  String toString() => 'WeatherObservation(${toMap()})';
}

class WeatherException implements Exception {
  final String message;
  WeatherException(this.message);
  @override
  String toString() => 'WeatherException: $message';
}

/// 기상청 API허브에서 현재 날씨를 받아 [WeatherCondition]으로 바꿔주는 서비스.
///
/// 인증키는 코드에 쓰지 말고 실행 시 주입한다:
///   flutter run --dart-define-from-file=secrets.json
///
/// 사용 예:
/// ```dart
/// final weather = WeatherService();
/// final cond = await weather.currentCondition(lat: 37.59, lon: 127.02);
/// calc.context = calc.context.copyWith(weather: cond);
/// ```
class WeatherService {
  static const _base = 'https://apihub.kma.go.kr/api/typ01';

  final String authKey;

  /// 위치를 모를 때 쓸 지점번호 (108 = 서울)
  final int defaultStation;

  /// 같은 지점은 이 시간 동안 다시 호출하지 않는다 (API 호출량 절약)
  final Duration cacheTtl;

  final http.Client _client;

  WeatherService({
    String? authKey,
    this.defaultStation = 108,
    this.cacheTtl = const Duration(minutes: 10),
    http.Client? client,
  })  : authKey = authKey ?? const String.fromEnvironment('KMA_AUTH_KEY'),
        _client = client ?? http.Client();

  static List<_Station>? _stations; // 앱 실행 중 1회만 받음
  final Map<int, (DateTime, WeatherObservation)> _cache = {};

  WeatherObservation? lastObservation;

  /// 점수 계산용. 실패해도 예외 대신 [WeatherCondition.unknown] (배수 1.0).
  Future<WeatherCondition> currentCondition({double? lat, double? lon}) async {
    try {
      final obs = await fetchLatest(lat: lat, lon: lon);
      return obs?.condition ?? WeatherCondition.unknown;
    } catch (_) {
      return WeatherCondition.unknown;
    }
  }

  /// 가장 가까운 AWS 지점의 최신 매분자료. 위치가 없으면 [defaultStation].
  Future<WeatherObservation?> fetchLatest({double? lat, double? lon}) async {
    if (authKey.isEmpty) {
      throw WeatherException(
          'KMA_AUTH_KEY가 비어 있음. --dart-define-from-file=secrets.json 으로 실행했는지 확인');
    }

    var stn = defaultStation;
    if (lat != null && lon != null) {
      stn = await nearestStation(lat, lon) ?? defaultStation;
    }

    final cached = _cache[stn];
    if (cached != null && DateTime.now().difference(cached.$1) < cacheTtl) {
      return lastObservation = cached.$2;
    }

    // 관측값이 API에 올라오기까지 1~수 분 지연이 있어서 조금씩 과거로 재시도
    final now = _kstNow();
    for (final back in const [1, 3, 6, 10]) {
      final tm = now.subtract(Duration(minutes: back));
      final text = await _get('$_base/cgi-bin/url/nph-aws2_min', {
        'tm2': _fmt(tm),
        'stn': '$stn',
        'disp': '0',
        'help': '1',
      });
      final obs = parseMinuteData(text, station: stn);
      if (obs != null) {
        _cache[stn] = (DateTime.now(), obs);
        return lastObservation = obs;
      }
    }
    return null;
  }

  /// 위경도에서 가장 가까운 AWS 지점번호
  Future<int?> nearestStation(double lat, double lon) async {
    try {
      _stations ??= parseStationList(await _get('$_base/url/stn_inf.php', {
        'inf': 'AWS',
        'stn': '',
        'tm': _fmt(_kstNow()),
        'help': '1',
      }));
    } catch (_) {
      return null;
    }
    final list = _stations!;
    if (list.isEmpty) return null;

    _Station? best;
    var bestD = double.infinity;
    for (final s in list) {
      final dx = (s.lon - lon) * math.cos(lat * math.pi / 180);
      final dy = s.lat - lat;
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    return best?.id;
  }

  Future<String> _get(String url, Map<String, String> params) async {
    final uri = Uri.parse(url)
        .replace(queryParameters: {...params, 'authKey': authKey});
    final res = await _client.get(uri).timeout(const Duration(seconds: 8));
    // 응답이 EUC-KR 텍스트라 숫자/헤더만 쓰는 용도로 latin1로 읽는다
    final body = latin1.decode(res.bodyBytes, allowInvalid: true);
    if (res.statusCode != 200) {
      throw WeatherException('HTTP ${res.statusCode}: ${body.trim()}');
    }
    return body;
  }

  void dispose() => _client.close();

  // ───────────────────────── 파서 (순수 함수, 테스트 가능) ─────────────────────────

  static const _defaultMinuteColumns = [
    'YYMMDDHHMI', 'STN', 'WD1', 'WS1', 'WDS', 'WSS', 'WD10', 'WS10', 'TA',
    'RE', 'RN-15M', 'RN-60M', 'RN-12H', 'RN-DAY', 'HM', 'PA', 'PS', 'TD',
  ];

  /// nph-aws2_min 텍스트 응답 → 해당 지점의 가장 최근 관측 1건
  static WeatherObservation? parseMinuteData(String text, {int? station}) {
    var cols = _defaultMinuteColumns;
    WeatherObservation? latest;

    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#')) {
        final tokens = line
            .replaceAll('#', ' ')
            .trim()
            .split(RegExp(r'\s+'))
            .map((t) => t.toUpperCase())
            .toList();
        if (tokens.contains('YYMMDDHHMI') && tokens.contains('TA')) {
          cols = tokens;
        }
        continue;
      }

      final v = line.split(RegExp(r'[\s,]+'));
      if (v.isEmpty || !RegExp(r'^\d{12}$').hasMatch(v[0])) continue;

      String? f(String name) {
        final i = cols.indexOf(name);
        return (i >= 0 && i < v.length) ? v[i] : null;
      }

      final stn = int.tryParse(f('STN') ?? '');
      if (station != null && stn != null && stn != station) continue;

      final re = _num(f('RE'));
      final obs = WeatherObservation(
        station: stn ?? station ?? -1,
        observedAt: _parseTm(v[0]),
        temperature: _num(f('TA')),
        precipitationDetected: re == null ? null : re >= 1,
        rain15m: _num(f('RN-15M')),
        windSpeed: _num(f('WS10')),
      );
      if (latest == null || !obs.observedAt.isBefore(latest.observedAt)) {
        latest = obs;
      }
    }
    return latest;
  }

  /// stn_inf.php?inf=AWS 텍스트 응답 → 지점 목록
  static List<_Station> parseStationList(String text) {
    var idI = 0, lonI = 1, latI = 2;
    final out = <_Station>[];
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) {
        final t = line
            .replaceAll('#', ' ')
            .trim()
            .split(RegExp(r'\s+'))
            .map((e) => e.toUpperCase())
            .toList();
        if (t.contains('LON') && t.contains('LAT')) {
          final id = t.indexWhere((e) => e == 'STN_ID' || e == 'STN');
          if (id >= 0) idI = id;
          lonI = t.indexOf('LON');
          latI = t.indexOf('LAT');
        }
        continue;
      }
      final v = line.split(RegExp(r'\s+'));
      if (v.length <= math.max(idI, math.max(lonI, latI))) continue;
      final id = int.tryParse(v[idI]);
      final lon = double.tryParse(v[lonI]);
      final lat = double.tryParse(v[latI]);
      if (id == null || lon == null || lat == null) continue;
      if (lat < 30 || lat > 40 || lon < 120 || lon > 135) continue; // 국내 범위만
      out.add(_Station(id, lat, lon));
    }
    return out;
  }

  /// 결측값(-99 등)은 null
  static double? _num(String? s) {
    if (s == null) return null;
    final d = double.tryParse(s);
    if (d == null || d <= -90) return null;
    return d;
  }

  static DateTime _parseTm(String s) => DateTime(
        int.parse(s.substring(0, 4)),
        int.parse(s.substring(4, 6)),
        int.parse(s.substring(6, 8)),
        int.parse(s.substring(8, 10)),
        int.parse(s.substring(10, 12)),
      );

  /// 기기 시간대와 상관없이 한국 시각
  static DateTime _kstNow() => DateTime.now().toUtc().add(const Duration(hours: 9));

  static String _fmt(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}'
      '${t.month.toString().padLeft(2, '0')}'
      '${t.day.toString().padLeft(2, '0')}'
      '${t.hour.toString().padLeft(2, '0')}'
      '${t.minute.toString().padLeft(2, '0')}';
}

class _Station {
  final int id;
  final double lat;
  final double lon;
  const _Station(this.id, this.lat, this.lon);
}
