import 'dart:async';
import 'dart:convert';

import 'package:flutter_naver_map/flutter_naver_map.dart' show NLatLng;
import 'package:http/http.dart' as http;

import '../config/secrets.dart';

/// 화면에 그대로 보여줄 수 있는 한국어 메시지를 담은 예외.
class GeoException implements Exception {
  final String message;
  const GeoException(this.message);
  @override
  String toString() => message;
}

/// 네이버 Directions 5 경로 결과.
class DrivingRoute {
  /// 경로 거리(m)
  final double distanceMeters;

  /// 경로를 따라 그릴 좌표들
  final List<NLatLng> path;

  const DrivingRoute({required this.distanceMeters, required this.path});
}

/// 네이버 클라우드 Maps REST API(Geocoding / Reverse Geocoding / Directions 5) 호출.
/// 키는 lib/config/secrets.dart (Git에 올라가지 않음)에서 읽는다.
class NaverGeoService {
  NaverGeoService._();

  static const _host = 'maps.apigw.ntruss.com';
  static const _timeout = Duration(seconds: 10);

  static Map<String, String> get _headers {
    if (Secrets.naverApiKeyId.isEmpty || Secrets.naverApiKey.isEmpty) {
      throw const GeoException('네이버 API 키가 없습니다. lib/config/secrets.dart 를 확인해주세요');
    }
    return {
      'x-ncp-apigw-api-key-id': Secrets.naverApiKeyId,
      'x-ncp-apigw-api-key': Secrets.naverApiKey,
      'Accept': 'application/json',
    };
  }

  static Future<Map<String, dynamic>> _get(String path, Map<String, String> query) async {
    final http.Response res;
    try {
      res = await http.get(Uri.https(_host, path, query), headers: _headers).timeout(_timeout);
    } on TimeoutException {
      throw const GeoException('응답이 늦어지고 있어요. 잠시 후 다시 시도해주세요');
    } on GeoException {
      rethrow;
    } catch (_) {
      throw const GeoException('네트워크 연결을 확인해주세요');
    }

    final body = utf8.decode(res.bodyBytes);
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {}

    if (res.statusCode != 200) {
      // 예) {"error":{"errorCode":400,"code":1,"message":"출발지와 도착지가 동일합니다..."}}
      final message = (json?['error'] as Map?)?['message'] as String?;
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw const GeoException('네이버 API 인증에 실패했습니다. 키와 등록한 API를 확인해주세요');
      }
      throw GeoException(message ?? '요청에 실패했습니다 (${res.statusCode})');
    }
    return json ?? {};
  }

  /// 주소 → 좌표. 결과가 없으면 null.
  /// (장소 이름이 아니라 주소만 검색된다. 예: "서울 강남구 테헤란로 152")
  static Future<NLatLng?> geocode(String address) async {
    final json = await _get('/map-geocode/v2/geocode', {'query': address});
    final list = json['addresses'] as List? ?? const [];
    if (list.isEmpty) return null;
    final first = list.first as Map<String, dynamic>;
    final lng = double.tryParse('${first['x']}');
    final lat = double.tryParse('${first['y']}');
    if (lat == null || lng == null) return null;
    return NLatLng(lat, lng);
  }

  /// 좌표 → 주소 문자열. 주소를 찾지 못하면 null.
  static Future<String?> reverseGeocode(NLatLng point) async {
    final json = await _get('/map-reversegeocode/v2/gc', {
      'coords': '${point.longitude},${point.latitude}',
      'orders': 'roadaddr,addr',
      'output': 'json',
    });
    final results = (json['results'] as List? ?? const []).cast<Map<String, dynamic>>();

    String region(Map<String, dynamic> r) {
      final reg = r['region'] as Map<String, dynamic>? ?? const {};
      return [
        for (final k in ['area1', 'area2', 'area3'])
          ((reg[k] as Map?)?['name'] as String?) ?? '',
      ].where((e) => e.isNotEmpty).join(' ');
    }

    for (final r in results) {
      final land = r['land'] as Map<String, dynamic>?;
      if (land == null) continue;
      if (r['name'] == 'roadaddr') {
        final road = land['name'] as String? ?? '';
        final no = land['number1'] as String? ?? '';
        if (road.isEmpty) continue;
        final reg = r['region'] as Map<String, dynamic>? ?? const {};
        final head = [
          for (final k in ['area1', 'area2'])
            ((reg[k] as Map?)?['name'] as String?) ?? '',
        ].where((e) => e.isNotEmpty).join(' ');
        return '$head $road $no'.trim();
      }
      if (r['name'] == 'addr') {
        final n1 = land['number1'] as String? ?? '';
        final n2 = land['number2'] as String? ?? '';
        final lot = n2.isEmpty ? n1 : '$n1-$n2';
        return '${region(r)} $lot'.trim();
      }
    }
    return null;
  }

  /// 두 지점 사이 경로(자동차전용도로 제외 옵션). 킥보드 시간은 호출하는 쪽에서 거리로 환산한다.
  static Future<DrivingRoute> drivingRoute(NLatLng start, NLatLng goal) async {
    const option = 'traavoidcaronly';
    final json = await _get('/map-direction/v1/driving', {
      'start': '${start.longitude},${start.latitude}',
      'goal': '${goal.longitude},${goal.latitude}',
      'option': option,
    });

    final routes = (json['route'] as Map<String, dynamic>?)?[option] as List?;
    if (routes == null || routes.isEmpty) {
      throw GeoException((json['message'] as String?) ?? '경로를 찾지 못했습니다');
    }
    final route = routes.first as Map<String, dynamic>;
    final distance = ((route['summary'] as Map)['distance'] as num).toDouble();
    final path = [
      for (final p in (route['path'] as List))
        NLatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()), // path는 [경도, 위도] 순서
    ];
    return DrivingRoute(distanceMeters: distance, path: path);
  }
}
