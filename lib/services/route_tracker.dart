import 'dart:math';

import 'package:flutter_naver_map/flutter_naver_map.dart' show NLatLng;

import '../utils/geo_math.dart';
import 'naver_geo_service.dart' show RouteGuide;

/// 현재 위치를 경로에 대어 본 결과.
class GuidanceState {
  /// 경로 시작점부터 진행한 거리(m)
  final double progressMeters;

  /// 도착지까지 남은 거리(m)
  final double remainingMeters;

  /// 경로에서 벗어난 거리(m). 경로 위면 0에 가깝다.
  final double offRouteMeters;

  /// [RouteTracker.offRouteThresholdMeters] 이상 벗어났는지
  final bool isOffRoute;

  /// 도착 반경 안에 들어왔는지
  final bool arrived;

  /// 아직 지나지 않은 가장 가까운 안내. 안내가 없거나 모두 지났으면 null.
  final RouteGuide? nextGuide;

  /// [nextGuide]까지 남은 거리(m)
  final double? distanceToNextMeters;

  const GuidanceState({
    required this.progressMeters,
    required this.remainingMeters,
    required this.offRouteMeters,
    required this.isOffRoute,
    required this.arrived,
    required this.nextGuide,
    required this.distanceToNextMeters,
  });
}

/// 경로(path)와 안내(guides)를 들고 있다가, GPS 위치가 들어올 때마다
/// "경로상 어디쯤인지 / 다음 안내까지 얼마나 남았는지 / 경로를 벗어났는지"를 계산한다.
///
/// 지도·GPS와 무관한 순수 계산이라 단위 테스트가 가능하다.
class RouteTracker {
  /// 이 거리(m) 이상 경로에서 떨어지면 "경로 이탈"로 본다.
  static const offRouteThresholdMeters = 50.0;

  /// 도착지까지 남은 거리가 이 값(m) 이하면 도착으로 본다.
  static const arrivalRadiusMeters = 25.0;

  /// 안내 지점 이 거리(m) 안으로 들어오면 그 안내는 "지난 것"으로 본다.
  /// (GPS 오차로 회전 지점을 정확히 못 밟는 경우 대비)
  static const guidePassMarginMeters = 10.0;

  // 현재 위치 근처만 먼저 찾을 때 앞쪽으로 볼 구간 수
  static const _searchAhead = 80;

  final List<NLatLng> path;
  final List<RouteGuide> guides;

  late final List<double> _cumulative; // _cumulative[i] = 시작~i번째 좌표 누적 거리
  late final List<double> _guideAt; // guides[i]가 있는 경로상 위치(m)
  int _segmentHint = 0; // 직전에 가장 가까웠던 구간. 경로가 겹치는 곳에서 뒤로 튀는 걸 막는다.

  RouteTracker({required this.path, this.guides = const []}) {
    assert(path.length >= 2, '경로 좌표가 2개 이상 필요합니다');
    _cumulative = List<double>.filled(path.length, 0);
    for (var i = 1; i < path.length; i++) {
      _cumulative[i] = _cumulative[i - 1] + haversineMeters(path[i - 1], path[i]);
    }
    _guideAt = [
      for (final g in guides) _cumulative[g.pointIndex.clamp(0, path.length - 1)],
    ];
  }

  double get totalMeters => _cumulative.last;

  /// 경로 시작점에서 [meters]만큼 간 지점의 좌표. (시뮬레이션용)
  NLatLng pointAt(double meters) {
    final d = meters.clamp(0.0, totalMeters);
    for (var i = 1; i < path.length; i++) {
      if (_cumulative[i] >= d) {
        final seg = _cumulative[i] - _cumulative[i - 1];
        final t = seg == 0 ? 0.0 : (d - _cumulative[i - 1]) / seg;
        final a = path[i - 1];
        final b = path[i];
        return NLatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
      }
    }
    return path.last;
  }

  /// 현재 위치 [p]를 경로에 대어 안내 상태를 계산한다.
  GuidanceState update(NLatLng p) {
    final hit = _nearest(p);
    final progress = hit.along;
    final remaining = max(0.0, totalMeters - progress);

    RouteGuide? next;
    double? toNext;
    for (var i = 0; i < guides.length; i++) {
      final ahead = _guideAt[i] - progress;
      if (ahead > guidePassMarginMeters) {
        next = guides[i];
        toNext = ahead;
        break;
      }
    }

    return GuidanceState(
      progressMeters: progress,
      remainingMeters: remaining,
      offRouteMeters: hit.distance,
      isOffRoute: hit.distance >= offRouteThresholdMeters,
      arrived: remaining <= arrivalRadiusMeters,
      nextGuide: next,
      distanceToNextMeters: toNext,
    );
  }

  // ---------------- 내부: 경로 위 가장 가까운 점 찾기 ----------------

  ({double distance, double along, int segment}) _nearest(NLatLng p) {
    final last = path.length - 2; // 마지막 구간 인덱스
    final from = max(0, _segmentHint - 3);
    final to = min(last, _segmentHint + _searchAhead);

    var best = _scan(p, from, to);
    // 근처에서 못 찾으면(많이 벗어났거나 경로가 크게 꼬임) 전체를 다시 훑는다.
    if (best.distance > offRouteThresholdMeters && (from > 0 || to < last)) {
      final all = _scan(p, 0, last);
      if (all.distance < best.distance) best = all;
    }
    _segmentHint = best.segment;
    return best;
  }

  ({double distance, double along, int segment}) _scan(NLatLng p, int from, int to) {
    var bestDist = double.infinity;
    var bestAlong = 0.0;
    var bestSeg = from;

    for (var i = from; i <= to; i++) {
      final a = path[i];
      final b = path[i + 1];

      // a 를 원점으로 하는 평면 좌표(m). 수백 m 범위에서는 이 근사로 충분하다.
      final mPerLat = 111320.0;
      final mPerLng = 111320.0 * cos(a.latitude * pi / 180);
      final bx = (b.longitude - a.longitude) * mPerLng;
      final by = (b.latitude - a.latitude) * mPerLat;
      final px = (p.longitude - a.longitude) * mPerLng;
      final py = (p.latitude - a.latitude) * mPerLat;

      final len2 = bx * bx + by * by;
      final t = len2 == 0 ? 0.0 : ((px * bx + py * by) / len2).clamp(0.0, 1.0);
      final dx = px - bx * t;
      final dy = py - by * t;
      final dist = sqrt(dx * dx + dy * dy);

      if (dist < bestDist) {
        bestDist = dist;
        bestSeg = i;
        bestAlong = _cumulative[i] + (_cumulative[i + 1] - _cumulative[i]) * t;
      }
    }
    return (distance: bestDist, along: bestAlong, segment: bestSeg);
  }
}
