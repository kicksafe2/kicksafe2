import 'dart:math';

import 'package:flutter_naver_map/flutter_naver_map.dart' show NLatLng;

/// 두 좌표 사이의 지표면 거리(m). (Haversine)
double haversineMeters(NLatLng a, NLatLng b) {
  const r = 6371000.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h = pow(sin(dLat / 2), 2) +
      cos(rad(a.latitude)) * cos(rad(b.latitude)) * pow(sin(dLng / 2), 2);
  return 2 * r * asin(sqrt(h));
}
