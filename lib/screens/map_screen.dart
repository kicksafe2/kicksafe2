import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

import '../config/app_config.dart';
import '../routes/app_routes.dart';
import '../services/naver_geo_service.dart';
import '../widgets/kicksafe_ui.dart';

/// Figma 디자인(MapScreen.tsx): 주행 경로 설정 화면.
///
/// 현재 위치(GPS) + 도착지 입력 → 경로 탐색 → 예상 주행 시간 표시.
/// 예상 시간이 [AppConfig.maxRideMinutes]를 넘으면 주행 차단 화면으로 이동하고,
/// 이하면 "주행 시작"이 나타난다.
///
/// - 지도: 네이버 지도 SDK
/// - 주소/좌표 변환·경로 거리: 네이버 Geocoding / Reverse Geocoding / Directions 5
/// - 예상 시간: 경로 거리 ÷ 킥보드 평균 속도([AppConfig.avgKickboardSpeedKmh])
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _seoulCityHall = NLatLng(37.5666, 126.9784);
  static const _panelBottomPadding = 360.0; // 하단 패널이 가리는 높이(카메라 여백용)

  final _currentController = TextEditingController();
  final _destController = TextEditingController();

  NaverMapController? _map;

  // 현재 위치(GPS)와, 그 좌표를 주소로 바꿔 입력칸에 채운 문자열
  NLatLng? _gpsLatLng;
  String _autoCurrentText = '';

  // 도착지: 지도 탭으로 정했을 때 좌표와, 그때 입력칸에 채운 문자열
  NLatLng? _tappedDest;
  String _tappedDestText = '';

  bool _locating = true;
  bool _searching = false;
  bool _driving = false;
  int? _estimatedMinutes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _locateMe();
  }

  @override
  void dispose() {
    _currentController.dispose();
    _destController.dispose();
    super.dispose();
  }

  // ---------------- 현재 위치 ----------------

  Future<void> _locateMe() async {
    setState(() {
      _locating = true;
      _currentController.text = '현재 위치 확인 중...';
    });

    NLatLng? here;
    String? problem;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        problem = '기기의 위치(GPS)가 꺼져 있어요';
      } else {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          problem = '위치 권한이 필요해요. 설정에서 허용하거나 현재 위치를 직접 입력해주세요';
        } else {
          Position? pos;
          try {
            pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 10),
              ),
            );
          } on TimeoutException {
            pos = await Geolocator.getLastKnownPosition();
          }
          if (pos == null) {
            problem = '현재 위치를 가져오지 못했어요';
          } else {
            here = NLatLng(pos.latitude, pos.longitude);
          }
        }
      }
    } catch (_) {
      problem = '현재 위치를 가져오지 못했어요';
    }

    if (!mounted) return;
    if (here == null) {
      setState(() {
        _locating = false;
        _gpsLatLng = null;
        _autoCurrentText = '';
        _currentController.text = '';
        _error = problem;
      });
      return;
    }

    String text;
    try {
      text = await NaverGeoService.reverseGeocode(here) ?? '현재 위치 (주소 정보 없음)';
    } on GeoException {
      text = '현재 위치';
    }
    if (!mounted) return;
    setState(() {
      _locating = false;
      _gpsLatLng = here;
      _autoCurrentText = text;
      _currentController.text = text;
      _error = null;
    });
    _showMyLocationOnMap();
  }

  void _showMyLocationOnMap() {
    final map = _map;
    final here = _gpsLatLng;
    if (map == null || here == null) return;
    map.setLocationTrackingMode(NLocationTrackingMode.noFollow);
    map.updateCamera(NCameraUpdate.scrollAndZoomTo(target: here, zoom: 15)
      ..setAnimation(duration: const Duration(milliseconds: 500)));
  }

  // ---------------- 지도 탭으로 도착지 선택 ----------------

  Future<void> _onMapTapped(NLatLng latLng) async {
    FocusScope.of(context).unfocus();
    _resetEstimate();

    final map = _map;
    if (map != null) {
      await map.clearOverlays();
      await map.addOverlay(NMarker(
        id: 'goal',
        position: latLng,
        caption: const NOverlayCaption(text: '도착'),
      ));
    }

    String text;
    try {
      text = await NaverGeoService.reverseGeocode(latLng) ?? '선택한 위치';
    } on GeoException {
      text = '선택한 위치';
    }
    if (!mounted) return;
    setState(() {
      _tappedDest = latLng;
      _tappedDestText = text;
      _destController.text = text;
      _error = null;
    });
  }

  void _resetEstimate() {
    if (_estimatedMinutes != null || _error != null) {
      setState(() {
        _estimatedMinutes = null;
        _error = null;
      });
    }
  }

  // ---------------- 경로 탐색 ----------------

  Future<void> _searchRoute() async {
    FocusScope.of(context).unfocus();
    final destText = _destController.text.trim();
    if (destText.isEmpty || _searching) return;

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      // 출발지: 현재 위치 칸을 직접 고치지 않았으면 GPS 좌표, 고쳤으면 그 주소를 좌표로 변환
      NLatLng? start;
      final currentText = _currentController.text.trim();
      if (_gpsLatLng != null && currentText == _autoCurrentText) {
        start = _gpsLatLng;
      } else if (currentText.isNotEmpty) {
        start = await NaverGeoService.geocode(currentText);
        if (start == null) {
          throw const GeoException('현재 위치 주소를 찾지 못했어요. 도로명 주소로 입력해주세요');
        }
      } else {
        throw const GeoException('현재 위치를 알 수 없어요. 현재 위치 칸에 주소를 입력해주세요');
      }

      // 도착지: 지도에서 직접 찍은 지점이면 그 좌표, 아니면 입력한 주소를 좌표로 변환
      NLatLng? goal;
      if (_tappedDest != null && destText == _tappedDestText) {
        goal = _tappedDest;
      } else {
        goal = await NaverGeoService.geocode(destText);
        if (goal == null) {
          throw const GeoException(
            '도착지를 찾지 못했어요. 도로명 주소(예: 서울 강남구 테헤란로 152)로 입력하거나 지도를 눌러 선택해주세요',
          );
        }
      }

      final route = await NaverGeoService.drivingRoute(start!, goal!);
      final minutes = _kickboardMinutes(route.distanceMeters);
      await _drawRoute(start, goal, route.path);

      if (!mounted) return;
      if (minutes > AppConfig.maxRideMinutes) {
        setState(() => _searching = false);
        await Navigator.of(context).pushNamed(
          AppRoutes.drivingBlocked,
          arguments: {'estimatedMinutes': minutes},
        );
        // 차단 화면에서 돌아오면 다시 탐색할 수 있게 초기화
        if (mounted) _resetEstimate();
        return;
      }
      setState(() {
        _estimatedMinutes = minutes;
        _searching = false;
      });
    } on GeoException catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = '경로를 계산하지 못했어요. 잠시 후 다시 시도해주세요';
      });
    }
  }

  int _kickboardMinutes(double meters) {
    final hours = (meters / 1000) / AppConfig.avgKickboardSpeedKmh;
    return max(1, (hours * 60).ceil());
  }

  Future<void> _drawRoute(NLatLng start, NLatLng goal, List<NLatLng> path) async {
    final map = _map;
    if (map == null) return;
    await map.clearOverlays();
    await map.addOverlayAll({
      NPathOverlay(
        id: 'route',
        coords: path,
        width: 6,
        color: const Color(0xFF9333EA),
        outlineWidth: 1,
        outlineColor: Colors.white,
      ),
      NMarker(id: 'start', position: start, caption: const NOverlayCaption(text: '출발')),
      NMarker(id: 'goal', position: goal, caption: const NOverlayCaption(text: '도착')),
    });
    await map.updateCamera(
      NCameraUpdate.fitBounds(
        NLatLngBounds.from([start, goal, ...path]),
        padding: const EdgeInsets.fromLTRB(48, 48, 48, _panelBottomPadding),
      )..setAnimation(duration: const Duration(milliseconds: 600)),
    );
  }

  // ---------------- 주행 시작 ----------------

  /// TODO: 실제 주행(센서 연동) 기능이 생기기 전까지는 원본 디자인처럼
  /// 잠시 뒤 점수 결과 화면으로 넘어가는 데모 동작이다. 점수는 임의 값(80~100).
  Future<void> _startDriving() async {
    if (_driving) return;
    setState(() => _driving = true);
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final score = 80 + Random().nextInt(21);
    setState(() => _driving = false);
    await Navigator.of(context).pushNamed(AppRoutes.scoreResult, arguments: {'score': score});
  }

  void _goHome() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacementNamed(AppRoutes.home);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: KsColors.gray50,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            KsHeader(title: '주행 경로 설정', onBack: _goHome),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: NaverMap(
                      options: const NaverMapViewOptions(
                        initialCameraPosition: NCameraPosition(target: _seoulCityHall, zoom: 14),
                        locationButtonEnable: true,
                        scaleBarEnable: false,
                      ),
                      onMapReady: (controller) {
                        _map = controller;
                        _showMyLocationOnMap();
                      },
                      onMapTapped: (point, latLng) => _onMapTapped(latLng),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: keyboard),
                      child: _buildPanel(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel() {
    final minutes = _estimatedMinutes;
    final canSearch = _destController.text.trim().isNotEmpty && !_searching && !_locating;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KsLabeledField(
              label: '현재 위치',
              icon: Icons.location_on_outlined,
              controller: _currentController,
              hint: '현재 위치',
              fieldHeight: 48,
              onChanged: (_) => _resetEstimate(),
              suffix: SizedBox(
                height: 48,
                child: IconButton(
                  onPressed: _locating ? null : _locateMe,
                  icon: const Icon(Icons.my_location, color: KsColors.purple600),
                  tooltip: '현재 위치로 다시 설정',
                ),
              ),
            ),
            const SizedBox(height: 12),
            KsLabeledField(
              label: '도착지',
              icon: Icons.gps_fixed,
              controller: _destController,
              hint: '도착지 주소를 입력하거나 지도를 눌러 선택',
              fieldHeight: 48,
              onChanged: (_) {
                _resetEstimate();
                setState(() {});
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: KsColors.red600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: KsColors.red600, fontSize: 13, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            if (minutes != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: KsColors.purple50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KsColors.purple200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('예상 주행 시간', style: TextStyle(color: KsColors.gray500, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      '${minutes ~/ 60}시간 ${minutes % 60}분',
                      style: const TextStyle(
                        color: KsColors.purple600,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (minutes == null)
              KsGradientButton(
                label: _searching ? '검색 중...' : '경로 탐색',
                onPressed: canSearch ? _searchRoute : null,
                trailing: _searching
                    ? null
                    : const Icon(Icons.search, color: Colors.white, size: 20),
              )
            else
              _buildStartButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return Opacity(
      opacity: _driving ? 0.6 : 1,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [KsColors.green600, KsColors.emerald700]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: KsColors.green600.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _driving ? null : _startDriving,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_driving)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  else
                    const Icon(Icons.navigation, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _driving ? '주행 중...' : '주행 시작',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
