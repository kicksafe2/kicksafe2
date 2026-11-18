import 'package:flutter_naver_map/flutter_naver_map.dart' show NLatLng;
import 'package:flutter_test/flutter_test.dart';
import 'package:kicksafe/services/naver_geo_service.dart' show RouteGuide;
import 'package:kicksafe/services/route_tracker.dart';

/// 북쪽으로 곧게 뻗은 약 1.1km 경로(위도 0.0001° ≈ 11.1m 간격, 100구간).
List<NLatLng> _straightPath() => [
      for (var i = 0; i <= 100; i++) NLatLng(37.5000 + i * 0.0001, 127.0000),
    ];

RouteTracker _tracker() => RouteTracker(
      path: _straightPath(),
      guides: const [
        RouteGuide(pointIndex: 40, instruction: '우회전', distanceFromPrevMeters: 444),
        RouteGuide(pointIndex: 100, instruction: '목적지', distanceFromPrevMeters: 666),
      ],
    );

void main() {
  test('출발점에서는 진행 0, 다음 안내는 첫 번째 회전', () {
    final s = _tracker().update(const NLatLng(37.5000, 127.0000));
    expect(s.progressMeters, closeTo(0, 1));
    expect(s.isOffRoute, isFalse);
    expect(s.arrived, isFalse);
    expect(s.nextGuide?.instruction, '우회전');
    expect(s.distanceToNextMeters, closeTo(444, 5));
  });

  test('이동하면 다음 안내까지 거리가 줄어든다', () {
    final t = _tracker();
    final a = t.update(const NLatLng(37.5010, 127.0000)); // 약 111m
    final b = t.update(const NLatLng(37.5030, 127.0000)); // 약 333m
    expect(a.progressMeters, closeTo(111, 3));
    expect(b.progressMeters, closeTo(333, 3));
    expect(b.distanceToNextMeters!, lessThan(a.distanceToNextMeters!));
    expect(b.nextGuide?.instruction, '우회전');
  });

  test('회전 지점을 지나면 다음 안내(목적지)로 넘어간다', () {
    final t = _tracker();
    final s = t.update(const NLatLng(37.5045, 127.0000)); // 회전점(37.5040)을 지남
    expect(s.nextGuide?.instruction, '목적지');
    expect(s.distanceToNextMeters, closeTo(totalAfter(s), 5));
  });

  test('회전 지점 10m 안에 들어오면 그 안내는 지난 것으로 본다', () {
    final t = _tracker();
    final s = t.update(const NLatLng(37.50395, 127.0000)); // 회전점 약 5m 전
    expect(s.nextGuide?.instruction, '목적지');
  });

  test('경로에서 옆으로 100m 벗어나면 이탈로 판정', () {
    final t = _tracker();
    // 경도 0.0011° ≈ 약 97m (위도 37.5 기준)
    final s = t.update(const NLatLng(37.5020, 127.0011));
    expect(s.isOffRoute, isTrue);
    expect(s.offRouteMeters, greaterThan(80));
  });

  test('경로에서 20m 정도 흔들리는 건 이탈이 아니다 (GPS 오차)', () {
    final t = _tracker();
    final s = t.update(const NLatLng(37.5020, 127.00023)); // 약 20m
    expect(s.isOffRoute, isFalse);
  });

  test('도착 반경 안에 들어오면 arrived', () {
    final t = _tracker();
    final s = t.update(const NLatLng(37.50995, 127.0000)); // 끝점 약 5m 전
    expect(s.arrived, isTrue);
    expect(s.remainingMeters, lessThan(25));
    expect(s.nextGuide, isNull);
  });

  test('GPS가 잠깐 뒤로 튀어도 진행도가 크게 되돌아가지 않는다', () {
    final t = _tracker();
    t.update(const NLatLng(37.5050, 127.0000)); // 약 555m
    final s = t.update(const NLatLng(37.5049, 127.0000)); // 약 11m 뒤
    expect(s.progressMeters, closeTo(544, 5));
  });

  test('pointAt은 경로 위의 좌표를 돌려준다', () {
    final t = _tracker();
    final p = t.pointAt(555);
    final s = t.update(p);
    expect(s.progressMeters, closeTo(555, 3));
    expect(s.isOffRoute, isFalse);
    expect(t.pointAt(-5).latitude, closeTo(37.5000, 1e-9));
    expect(t.pointAt(1e9).latitude, closeTo(37.5100, 1e-9));
  });

  test('안내가 없어도 거리 계산은 동작한다', () {
    final t = RouteTracker(path: _straightPath());
    final s = t.update(const NLatLng(37.5050, 127.0000));
    expect(s.nextGuide, isNull);
    expect(s.remainingMeters, closeTo(555, 5));
  });
}

double totalAfter(GuidanceState s) => s.remainingMeters;
