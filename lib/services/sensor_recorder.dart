import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../scoring/scoring.dart' show DrivingEventTypeLabel, ScoredEvent;
import 'ble_sensor_service.dart' show SensorReading;

/// 1초 분량(기본)의 원시 센서값 묶음. Firestore `imuLogs/{sessionId}/logs/{자동ID}` 문서 1개가 된다.
///
/// Firestore 는 배열 안의 배열을 못 쓰므로 값을 한 줄로 펴서 [stride]개씩 끊어 읽는다.
/// 한 샘플 = [t_ms, ax, ay, az, gx, gy, gz, speed_kmh(없으면 -1)] (stride 8)
class RawChunk {
  static const stride = 8;

  final int seq;

  /// 이 묶음의 첫 샘플 시각(주행 시작 기준 ms)
  final int tStartMs;
  final List<double> data;

  const RawChunk({required this.seq, required this.tStartMs, required this.data});

  int get count => data.length ~/ stride;

  Map<String, Object?> toMap() => {
        'seq': seq,
        'tStartMs': tStartMs,
        'count': count,
        'stride': stride,
        'columns': 't_ms,ax,ay,az,gx,gy,gz,speed_kmh',
        'data': data,
      };
}

/// 주행 중 들어오는 센서 원시값과 감점 이벤트를 기록한다.
///
/// 목적: 실주행에서 점수가 이상하게 나왔을 때, 어떤 값이 들어왔고 어떤 임계값에서 무엇이 잡혔는지
/// 되짚어 임계값을 근거 있게 다시 정하기 위함이다.
///
/// - 폰 파일(CSV, [directory] 지정 시): `<sessionId>_imu.csv`, `<sessionId>_events.csv`
/// - Firestore 등 외부 저장: [onChunk] 콜백으로 1초 묶음을 넘겨준다.
///
/// 순수 Dart(Firebase/BLE 의존 없음)라서 테스트에서 [now]를 넣어 시간을 흉내낼 수 있다.
class SensorRecorder {
  final String sessionId;
  final Directory? directory;
  final void Function(RawChunk chunk)? onChunk;
  final Duration chunkDuration;

  IOSink? _imuSink;
  IOSink? _eventSink;
  DateTime? _t0;
  DateTime? _chunkStart;
  final List<double> _chunk = [];
  int _chunkSeq = 0;
  int _chunkStartMs = 0;
  int _count = 0;
  bool _closed = false;
  Timer? _flushTimer;

  SensorRecorder({
    required this.sessionId,
    this.directory,
    this.onChunk,
    this.chunkDuration = const Duration(seconds: 1),
  });

  /// 기록한 센서 샘플 수
  int get count => _count;

  String? get imuPath => directory == null ? null : _path('imu');
  String? get eventsPath => directory == null ? null : _path('events');

  String _path(String kind) => '${directory!.path}${Platform.pathSeparator}${sessionId}_$kind.csv';

  /// 폴더를 만들고 CSV 머리줄을 쓴다. 실패해도 예외를 던지지 않고(주행을 막지 않음) 파일 기록만 끈다.
  Future<void> open() async {
    final dir = directory;
    if (dir == null) return;
    try {
      await dir.create(recursive: true);
      _imuSink = File(_path('imu')).openWrite();
      _imuSink!.writeln('t_ms,ax,ay,az,gx,gy,gz,speed_kmh,source');
      _eventSink = File(_path('events')).openWrite();
      _eventSink!.writeln('t_ms,type,penalty,base_penalty,multiplier');
      // 앱이 갑자기 꺼져도 최근 값이 남도록 주기적으로 디스크에 내려쓴다.
      _flushTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _imuSink?.flush();
        _eventSink?.flush();
      });
    } catch (e) {
      debugPrint('센서 기록 파일을 열지 못했어요: $e');
      _imuSink = null;
      _eventSink = null;
    }
  }

  int _ms(DateTime now) => now.difference(_t0 ?? now).inMilliseconds;

  /// 센서 샘플 1개를 기록한다. [speedKmh]는 그 시점 GPS 속도(없으면 null), [fake]는 디버그용 가짜 값.
  void addReading(SensorReading r, {DateTime? now, double? speedKmh, bool fake = false}) {
    if (_closed) return;
    final t = now ?? DateTime.now();
    _t0 ??= t;
    final ms = _ms(t);
    final speed = speedKmh ?? -1;
    _count++;

    _imuSink?.writeln('$ms,${_f(r.ax)},${_f(r.ay)},${_f(r.az)},'
        '${_f(r.gx)},${_f(r.gy)},${_f(r.gz)},${speed < 0 ? '' : speed.toStringAsFixed(1)},${fake ? 'fake' : 'sensor'}');

    if (onChunk != null) {
      _chunkStart ??= t;
      if (_chunk.isEmpty) _chunkStartMs = ms;
      _chunk.addAll([ms.toDouble(), _r3(r.ax), _r3(r.ay), _r3(r.az), _r3(r.gx), _r3(r.gy), _r3(r.gz), speed]);
      if (t.difference(_chunkStart!) >= chunkDuration) _emitChunk(t);
    }
  }

  /// 감점이 반영된 이벤트를 기록한다.
  void addEvent(ScoredEvent e, {DateTime? now}) {
    if (_closed) return;
    final ms = _ms(now ?? DateTime.now());
    _eventSink?.writeln('$ms,${e.type.label},${e.appliedPenalty},${e.basePenalty},${e.multiplier}');
  }

  /// 남은 묶음을 내보내고 파일을 닫는다. (주행 종료 시)
  Future<void> close({DateTime? now}) async {
    if (_closed) return;
    _flushTimer?.cancel();
    if (_chunk.isNotEmpty) _emitChunk(now ?? DateTime.now());
    _closed = true;
    try {
      await _imuSink?.flush();
      await _imuSink?.close();
      await _eventSink?.flush();
      await _eventSink?.close();
    } catch (e) {
      debugPrint('센서 기록 파일 닫기 실패: $e');
    }
    _imuSink = null;
    _eventSink = null;
  }

  void _emitChunk(DateTime now) {
    final chunk = RawChunk(seq: _chunkSeq++, tStartMs: _chunkStartMs, data: List<double>.of(_chunk));
    _chunk.clear();
    _chunkStart = now;
    onChunk?.call(chunk);
  }

  static String _f(double v) => v.toStringAsFixed(3);
  static double _r3(double v) => (v * 1000).roundToDouble() / 1000;
}
