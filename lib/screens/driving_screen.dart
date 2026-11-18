import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

import '../config/app_config.dart';
import '../routes/app_routes.dart';
import '../scoring/scoring.dart';
import '../services/ble_sensor_service.dart' show SensorReading;
import '../services/naver_geo_service.dart' show RouteGuide;
import '../services/ride_service.dart';
import '../services/route_tracker.dart';
import '../services/sensor_link.dart';
import '../services/sensor_log_storage.dart';
import '../services/sensor_recorder.dart';
import '../utils/event_text.dart';
import '../utils/route_text.dart';
import '../widgets/kicksafe_ui.dart';

/// 지도 화면이 주행 화면으로 넘겨주는 값.
class DrivingScreenArgs {
  final List<NLatLng> path;
  final List<RouteGuide> guides;
  final String originName;
  final String destinationName;
  final double distanceMeters; // 경로 전체 거리
  final int estimatedMinutes;

  const DrivingScreenArgs({
    required this.path,
    required this.guides,
    required this.originName,
    required this.destinationName,
    required this.distanceMeters,
    required this.estimatedMinutes,
  });
}

/// 주행 중 화면: 폰 GPS 위치가 바뀔 때마다 경로상 위치를 다시 계산해
/// "다음 안내 / 남은 거리 / 남은 시간"을 실시간으로 갱신한다.
///
/// - 위치: geolocator 위치 스트림
/// - 계산: [RouteTracker] (지도·GPS와 무관한 순수 계산)
/// - 디버그 빌드에서만 "시뮬레이션" 버튼이 보인다. 경로를 따라 가짜 위치를 흘려보내
///   걷지 않고도 안내가 바뀌는 걸 확인할 수 있다.
///
/// 점수: 센서(ESP32) BLE 값 → [RideScorer](1초 윈도우 이벤트 감지 + 감점) → 현재 점수.
/// 감점된 이벤트는 Firestore `scoreEvents/{sessionId}/events` 에 저장하고, 주행이 끝나면
/// 요약(점수·이벤트 횟수)을 `sessions` 에 남긴다. 센서가 연결되지 않으면 감점 없이 100점으로 기록한다.
/// 임계값은 lib/scoring/event_detector.dart 의 DetectorThresholds 한 곳에서 조정한다.
///
/// TODO: 경로 이탈 시 재탐색, 음성 안내, 주행 중 화면 꺼짐 방지(wakelock).
class DrivingScreen extends StatefulWidget {
  final DrivingScreenArgs args;
  const DrivingScreen({super.key, required this.args});

  @override
  State<DrivingScreen> createState() => _DrivingScreenState();
}

class _DrivingScreenState extends State<DrivingScreen> {
  static const _simSpeedMetersPerSecond = 12.0; // 시뮬레이션 속도(약 43km/h)
  static const _simTick = Duration(milliseconds: 1000);

  late final RouteTracker _tracker;
  late GuidanceState _state;

  NaverMapController? _map;
  NMarker? _me;
  StreamSubscription<Position>? _gpsSub;

  bool _hasFix = false; // 실제(또는 시뮬레이션) 위치를 한 번이라도 받았는지
  String? _gpsProblem;
  bool _finishing = false;

  // 주행 기록(Firestore sessions)용
  RideSession? _session;
  final _stopwatch = Stopwatch()..start();
  double _speedSumKmh = 0;
  int _speedCount = 0;
  double _maxSpeedKmh = 0;
  bool _usedSimulation = false;

  // 센서 기반 점수 (BLE → RideScorer → Firestore)
  static const _thresholds = DetectorThresholds();
  final RideScorer _scorer = RideScorer(
    thresholds: _thresholds,
    context: RideContext(isNight: isNightTime(DateTime.now())),
  );
  SensorRecorder? _recorder; // 원시 센서값 기록(폰 CSV + Firestore imuLogs)
  double? _lastSpeedKmh; // 가장 최근 GPS 속도(센서 기록에 같이 남김)
  final SensorLink _sensor = SensorLink();
  String? _lastEventText; // 방금 감점된 이벤트 표시(몇 초 뒤 사라짐)
  Timer? _eventTextTimer;
  Timer? _fakeSensorTimer; // 디버그 전용: 가짜 센서 값
  bool _usedFakeSensor = false;

  Timer? _simTimer;
  double _simMeters = 0;
  bool get _simulating => _simTimer != null;

  @override
  void initState() {
    super.initState();
    _tracker = RouteTracker(path: widget.args.path, guides: widget.args.guides);
    _state = _tracker.update(widget.args.path.first);
    _session = RideService.start(
      origin: widget.args.originName,
      destination: widget.args.destinationName,
      plannedDistanceMeters: widget.args.distanceMeters,
      estimatedMinutes: widget.args.estimatedMinutes,
    );
    _startGps();
    unawaited(_startRecorder());
    _sensor.status.addListener(_onSensorStatus);
    unawaited(_sensor.start(_onSensorReading));
  }

  /// 원시 센서값 기록을 연다. 실패해도 주행에는 영향이 없다.
  Future<void> _startRecorder() async {
    final session = _session;
    final dir = AppConfig.saveRawSensorToFile ? await sensorLogDirectory() : null;
    if (!mounted) return;
    final recorder = SensorRecorder(
      sessionId: session?.id ?? 'local-${DateTime.now().millisecondsSinceEpoch}',
      directory: dir,
      onChunk: AppConfig.saveRawSensorToFirestore && session != null
          ? (chunk) => RideService.saveImuChunk(session, chunk)
          : null,
    );
    await recorder.open();
    _recorder = recorder;
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _simTimer?.cancel();
    _fakeSensorTimer?.cancel();
    _eventTextTimer?.cancel();
    _sensor.status.removeListener(_onSensorStatus);
    _sensor.dispose();
    unawaited(_recorder?.close());
    super.dispose();
  }

  // ---------------- 센서 → 점수 ----------------

  void _onSensorStatus() {
    if (mounted) setState(() {});
  }

  void _onSensorReading(SensorReading r, {bool fake = false}) {
    if (!mounted || _finishing) return;
    _recorder?.addReading(r, speedKmh: _lastSpeedKmh, fake: fake);
    final events = _scorer.addReading(r);
    if (events.isNotEmpty) _handleScoredEvents(events);
  }

  void _handleScoredEvents(List<ScoredEvent> events) {
    for (final e in events) {
      _recorder?.addEvent(e);
    }
    RideService.saveScoreEvents(_session, events);
    HapticFeedback.mediumImpact();
    _eventTextTimer?.cancel();
    setState(() {
      _lastEventText = events.map((e) => '${e.type.ko} -${e.appliedPenalty}').join(', ');
    });
    _eventTextTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _lastEventText = null);
    });
  }

  // ---------------- GPS ----------------

  Future<void> _startGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setProblem('기기의 위치(GPS)가 꺼져 있어요. 켠 뒤 다시 들어와주세요');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _setProblem('위치 권한이 필요해요. 설정에서 위치 권한을 허용해주세요');
        return;
      }

      final settings = defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 3, // 3m 이상 움직였을 때만 갱신
              intervalDuration: const Duration(seconds: 1),
            )
          : const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3);

      _gpsSub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (pos) {
          if (_simulating) return; // 시뮬레이션 중에는 실제 GPS를 무시
          _onPosition(NLatLng(pos.latitude, pos.longitude), speedMps: pos.speed);
        },
        onError: (_) => _setProblem('위치를 가져오지 못했어요. GPS 신호를 확인해주세요'),
      );
    } catch (_) {
      _setProblem('위치를 가져오지 못했어요');
    }
  }

  void _setProblem(String message) {
    if (!mounted) return;
    setState(() => _gpsProblem = message);
  }

  // ---------------- 위치가 들어올 때마다 ----------------

  void _onPosition(NLatLng p, {double? speedMps}) {
    if (!mounted || _finishing) return;
    if (speedMps != null && speedMps >= 0) {
      final kmh = speedMps * 3.6;
      _lastSpeedKmh = kmh;
      _speedSumKmh += kmh;
      _speedCount++;
      _maxSpeedKmh = max(_maxSpeedKmh, kmh);
    }
    final next = _tracker.update(p);
    setState(() {
      _state = next;
      _hasFix = true;
      _gpsProblem = null;
    });
    _moveMapTo(p);
    if (next.arrived) _arrive();
  }

  Future<void> _moveMapTo(NLatLng p) async {
    final map = _map;
    if (map == null) return;
    final me = _me;
    if (me == null) {
      final marker = NMarker(id: 'me', position: p, caption: const NOverlayCaption(text: '현재'));
      _me = marker;
      await map.addOverlay(marker);
    } else {
      me.setPosition(p);
    }
    await map.updateCamera(
      NCameraUpdate.scrollAndZoomTo(target: p)..setAnimation(duration: const Duration(milliseconds: 800)),
    );
  }

  Future<void> _onMapReady(NaverMapController controller) async {
    _map = controller;
    await controller.addOverlayAll({
      NPathOverlay(
        id: 'route',
        coords: widget.args.path,
        width: 6,
        color: const Color(0xFF9333EA),
        outlineWidth: 1,
        outlineColor: Colors.white,
      ),
      NMarker(
        id: 'goal',
        position: widget.args.path.last,
        caption: const NOverlayCaption(text: '도착'),
      ),
    });
  }

  // ---------------- 가짜 센서(디버그 전용) ----------------

  /// 센서 없이 점수 흐름을 확인하려고 20ms(50Hz) 간격으로 가짜 값을 흘려보낸다.
  /// kind: crash(충격 1회) / brake(진행축 +1g → -1g) / turn(0.4초 회전)
  void _fakeSensor(String kind) {
    _fakeSensorTimer?.cancel();
    _usedFakeSensor = true;
    _usedSimulation = true;
    final endTick = switch (kind) { 'brake' => 220, 'turn' => 130, _ => 130 };
    var tick = 0;
    _fakeSensorTimer = Timer.periodic(const Duration(milliseconds: 20), (t) {
      final sec = tick * 0.02;
      var ax = 0.0, gx = 0.0, gz = 0.0;
      switch (kind) {
        case 'crash':
          if (tick == 60) {
            ax = 6.0; // 6g 충격 + 300°/s 회전
            gx = 300;
          }
        case 'brake':
          ax = sec < 2.0 ? 1.0 : -1.0; // 진행축 평균이 2g 바뀜(임계 0.8g)
        case 'turn':
          if (sec >= 1.0 && sec < 1.4) gz = 200; // 임계 140°/s
      }
      _onSensorReading(SensorReading(ax: ax, ay: 0, az: 1, gx: gx, gy: 0, gz: gz), fake: true);
      if (++tick >= endTick) t.cancel();
    });
  }

  // ---------------- 시뮬레이션(디버그 전용) ----------------

  void _toggleSimulation() {
    if (_simulating) {
      _simTimer?.cancel();
      setState(() => _simTimer = null);
      return;
    }
    _simMeters = _hasFix ? _state.progressMeters : 0;
    _usedSimulation = true;
    setState(() {
      _simTimer = Timer.periodic(_simTick, (_) {
        _simMeters += _simSpeedMetersPerSecond * _simTick.inSeconds;
        _onPosition(_tracker.pointAt(_simMeters), speedMps: _simSpeedMetersPerSecond);
      });
    });
  }

  // ---------------- 종료 ----------------

  Future<void> _arrive() async {
    if (_finishing) return;
    _finishing = true;
    _simTimer?.cancel();
    _simTimer = null;
    await _gpsSub?.cancel();
    if (!mounted) return;
    setState(() {}); // 도착 표시
    await Future<void>.delayed(const Duration(seconds: 2));
    await _goToScore(endedEarly: false);
  }

  Future<void> _confirmEnd() async {
    final end = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('주행을 종료할까요?'),
        content: const Text('지금까지의 주행으로 점수를 계산해요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속 주행')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('종료')),
        ],
      ),
    );
    if (end == true) {
      _finishing = true;
      _simTimer?.cancel();
      _simTimer = null;
      await _gpsSub?.cancel();
      await _goToScore(endedEarly: true);
    }
  }

  /// 주행 결과를 Firestore(sessions)에 기록하고 점수 화면으로 넘어간다.
  Future<void> _goToScore({required bool endedEarly}) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    _fakeSensorTimer?.cancel();
    await _sensor.stop(); // 센서 연결 해제

    // 아직 닫히지 않은 마지막 윈도우까지 판정
    final last = _scorer.flush();
    if (last.isNotEmpty) {
      for (final e in last) {
        _recorder?.addEvent(e);
      }
      RideService.saveScoreEvents(_session, last);
    }

    final rawPath = _recorder?.imuPath;
    final rawCount = _recorder?.count ?? 0;
    await _recorder?.close(); // 남은 묶음 저장 + 파일 닫기

    final sensorOk = _scorer.readingCount > 0;
    final score = _scorer.score; // 센서 값이 없으면 감점 없이 100점
    final counts = _scorer.eventCounts;
    final breakdown = _scorer.penaltyBreakdown;

    final seconds = _stopwatch.elapsed.inSeconds;
    final traveled = _state.arrived ? _tracker.totalMeters : _state.progressMeters;
    final avgKmh = _speedCount > 0
        ? _speedSumKmh / _speedCount
        : (seconds > 0 ? traveled / seconds * 3.6 : 0.0);

    final error = await RideService.finish(
      _session,
      score: score,
      endedEarly: endedEarly,
      distanceMeters: traveled,
      durationSeconds: seconds,
      avgSpeedKmh: avgKmh,
      maxSpeedKmh: _maxSpeedKmh,
      simulated: _usedSimulation,
      sensorConnected: sensorOk,
      sensorSamples: _scorer.readingCount,
      eventCounts: {for (final e in counts.entries) e.key.label: e.value},
      penaltyBreakdown: {for (final e in breakdown.entries) e.key.label: e.value},
      thresholds: _thresholds.toMap(),
      rawLogFile: rawPath,
      rawSamples: rawCount,
    );
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error), duration: const Duration(seconds: 6)));
    }

    final rawName = rawPath?.split(RegExp(r'[\\/]')).last;
    final notes = <String>[
      if (!sensorOk) '센서 데이터가 들어오지 않아 감점 없이 100점으로 기록됐어요',
      if (sensorOk && _usedFakeSensor) '가짜 센서 값(테스트)이 포함된 점수예요',
      if (rawName != null && rawCount > 0) '센서 원시값 $rawCount개를 폰에 기록했어요: $rawName',
    ];
    final notice = notes.isEmpty ? null : notes.join('\n');
    navigator.pushReplacementNamed(AppRoutes.scoreResult, arguments: {
      'score': score,
      'avgSpeedKmh': avgKmh,
      'hardBrakeCount': counts[DrivingEventType.hardBrake] ?? 0,
      'hardAccelCount': counts[DrivingEventType.hardAccel] ?? 0,
      'penaltyLines': [
        for (final e in breakdown.entries) '${e.key.ko} ${counts[e.key] ?? 0}회  -${e.value}점',
      ],
      'notice': notice,
    });
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmEnd();
      },
      child: Scaffold(
        backgroundColor: KsColors.gray50,
        body: Stack(
          children: [
            Positioned.fill(
              child: NaverMap(
                options: NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(target: widget.args.path.first, zoom: 17),
                  scaleBarEnable: false,
                  locationButtonEnable: false,
                ),
                onMapReady: _onMapReady,
              ),
            ),
            Positioned(top: 0, left: 0, right: 0, child: _buildGuidanceCard()),
            Align(alignment: Alignment.bottomCenter, child: _buildBottomPanel()),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceCard() {
    final s = _state;
    final guide = s.nextGuide;

    final String title;
    final String? distance;
    final IconData icon;
    if (s.arrived) {
      title = '목적지에 도착했어요!';
      distance = null;
      icon = Icons.flag;
    } else if (guide != null) {
      title = guide.instruction;
      distance = formatDistance(s.distanceToNextMeters ?? 0);
      icon = guideIcon(guide.instruction);
    } else {
      title = '경로를 따라 이동하세요';
      distance = formatDistance(s.remainingMeters);
      icon = Icons.straight;
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 16),
      decoration: BoxDecoration(
        gradient: KsColors.brandGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (distance != null)
                      Text(
                        guide != null ? '$distance 앞' : '남은 거리 $distance',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: distance != null ? 14 : 20,
                        fontWeight: distance != null ? FontWeight.w400 : FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_notice != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _notice!.warning
                    ? KsColors.red600.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _notice!.warning ? Icons.warning_amber_rounded : Icons.gps_not_fixed,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _notice!.text,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 안내 카드 아래에 띄우는 상태 메시지(우선순위: GPS 문제 > 경로 이탈 > 신호 대기).
  ({String text, bool warning})? get _notice {
    if (_gpsProblem != null) return (text: _gpsProblem!, warning: true);
    if (_hasFix && _state.isOffRoute) {
      return (text: '경로에서 벗어났어요. 경로선을 따라 이동해주세요', warning: true);
    }
    if (!_hasFix) {
      return (text: 'GPS 신호를 찾는 중이에요. 하늘이 트인 곳으로 이동해보세요', warning: false);
    }
    return null;
  }

  Widget _buildBottomPanel() {
    final remaining = _state.remainingMeters;
    final minutes = max(1, ((remaining / 1000) / AppConfig.avgKickboardSpeedKmh * 60).ceil());

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 18, 24, 18 + MediaQuery.of(context).padding.bottom),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.args.destinationName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: KsColors.gray500),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _stat(
                  '남은 거리',
                  _state.arrived ? '0m' : formatDistance(remaining),
                ),
              ),
              Expanded(child: _stat('남은 시간', _state.arrived ? '-' : '약 $minutes분')),
            ],
          ),
          const SizedBox(height: 12),
          _buildSensorRow(),
          if (kDebugMode) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (final k in const [('crash', '충돌'), ('brake', '급정거'), ('turn', '급회전')]) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _finishing ? null : () => _fakeSensor(k.$1),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KsColors.red600,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('가짜 ${k.$2}', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  if (k.$1 != 'turn') const SizedBox(width: 6),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (kDebugMode) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _finishing ? null : _toggleSimulation,
                    icon: Icon(_simulating ? Icons.stop : Icons.play_arrow),
                    label: Text(_simulating ? '시뮬레이션 중지' : '시뮬레이션'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: KsColors.purple600,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: KsGradientButton(
                  label: '주행 종료',
                  height: 52,
                  onPressed: _finishing ? null : _confirmEnd,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 센서 연결 상태 + 현재 점수 + 방금 감점된 이벤트.
  Widget _buildSensorRow() {
    final st = _sensor.status.value;
    final Color dot = switch (st) {
      SensorStatus.connected => KsColors.green600,
      SensorStatus.idle ||
      SensorStatus.searching ||
      SensorStatus.connecting ||
      SensorStatus.reconnecting =>
        const Color(0xFFF59E0B),
      _ => KsColors.red600,
    };
    final hasData = _scorer.readingCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: KsColors.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KsColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasData && !st.isOk ? '${st.label} (값 ${_scorer.readingCount}개 수신)' : st.label,
                  style: const TextStyle(fontSize: 13, color: KsColors.gray700),
                ),
              ),
              Text(
                '점수 ${_scorer.score}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: KsColors.purple600,
                ),
              ),
            ],
          ),
          if (_lastEventText != null) ...[
            const SizedBox(height: 6),
            Text(
              '⚠ $_lastEventText',
              style: const TextStyle(fontSize: 13, color: KsColors.red600, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: KsColors.gray500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: KsColors.purple600,
          ),
        ),
      ],
    );
  }
}
