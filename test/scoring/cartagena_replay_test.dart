// 카르타헤나 킥보드 공개 데이터(UPCT, CC BY 4.0)를 우리 센서 좌표계로 바꾼 CSV 를
// 실제 감지기+점수 계산기에 재생해서 임계값을 검증한다.
//
// 데이터는 저장소에 넣지 않았다. 환경변수 KICKSAFE_REPLAY_DIR 에 변환된 CSV 폴더를 지정했을 때만 실행되고,
// 없으면 건너뛴다. (CSV: t,ax,ay,az,gx,gy,gz — 50Hz, 단위 g / °/s, ax=진행·az=위)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kicksafe/scoring/scoring.dart';
import 'package:kicksafe/services/ble_sensor_service.dart';

class _Run {
  final Map<DrivingEventType, int> counts;
  final int score;
  final double minutes;
  _Run(this.counts, this.score, this.minutes);
  int c(DrivingEventType t) => counts[t] ?? 0;
}

List<SensorReading> _load(File f) {
  final lines = f.readAsLinesSync().skip(1);
  return [
    for (final l in lines)
      if (l.isNotEmpty)
        (() {
          final p = l.split(',').map(double.parse).toList();
          return SensorReading(ax: p[1], ay: p[2], az: p[3], gx: p[4], gy: p[5], gz: p[6]);
        })(),
  ];
}

/// [step] 개마다 1개만 넣어 전송 속도를 낮춘다. (50Hz → step 15 ≈ 3.3Hz)
_Run _replay(List<SensorReading> data,
    {int step = 1, DetectorThresholds thresholds = const DetectorThresholds()}) {
  final s = RideScorer(thresholds: thresholds);
  final start = DateTime(2026, 11, 18, 14);
  for (var i = 0; i < data.length; i += step) {
    s.addReading(data[i], now: start.add(Duration(milliseconds: (i * 20))));
  }
  s.flush(now: start.add(Duration(milliseconds: data.length * 20)));
  return _Run(s.eventCounts, s.score, data.length / 50 / 60);
}

void main() {
  final dirPath = Platform.environment['KICKSAFE_REPLAY_DIR'];
  final dir = dirPath == null ? null : Directory(dirPath);
  final skip = dir == null || !dir.existsSync() ? 'KICKSAFE_REPLAY_DIR 미지정' : null;

  String kind(String name) {
    if (name.contains('Riding')) return '주행';
    if (name.contains('overturn')) return '넘어짐';
    if (name.contains('collision')) return '충돌';
    return '기타';
  }

  test('실데이터 재생: 정상 주행 오탐 / 사고 검출', () {
    final files = dir!.listSync().whereType<File>().where((f) => f.path.endsWith('.csv')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final b = StringBuffer('\n폴더                                      종류   분   | 50Hz: 넘어짐 급가속 급정거 급회전 점수 | 3.3Hz: 넘어짐 급가속 급정거 급회전 점수\n');
    final rideFalls50 = <int>[];
    final rideFalls3 = <int>[];
    final accidentFalls50 = <String, int>{};
    final accidentFalls3 = <String, int>{};
    var rideMinutes = 0.0, rideHard50 = 0, rideTurn50 = 0;

    for (final f in files) {
      final name = f.uri.pathSegments.last.replaceAll('.csv', '');
      final data = _load(f);
      final a = _replay(data);
      final l = _replay(data, step: 15);
      final k = kind(name);
      String row(_Run r) =>
          '${r.c(DrivingEventType.fallImpact).toString().padLeft(4)} ${r.c(DrivingEventType.hardAccel).toString().padLeft(5)} '
          '${r.c(DrivingEventType.hardBrake).toString().padLeft(5)} ${r.c(DrivingEventType.sharpTurn).toString().padLeft(5)} ${r.score.toString().padLeft(4)}';
      b.writeln('${name.padRight(40)} ${k.padRight(3)} ${a.minutes.toStringAsFixed(1).padLeft(5)} | ${row(a)} | ${row(l)}');
      if (k == '주행') {
        rideFalls50.add(a.c(DrivingEventType.fallImpact));
        rideFalls3.add(l.c(DrivingEventType.fallImpact));
        rideMinutes += a.minutes;
        rideHard50 += a.c(DrivingEventType.hardAccel) + a.c(DrivingEventType.hardBrake);
        rideTurn50 += a.c(DrivingEventType.sharpTurn);
      } else {
        accidentFalls50[name] = a.c(DrivingEventType.fallImpact);
        accidentFalls3[name] = l.c(DrivingEventType.fallImpact);
      }
    }
    b.writeln('\n정상 주행 합계 ${rideMinutes.toStringAsFixed(1)}분: 급가속+급정거 ${rideHard50}건 '
        '(분당 ${(rideHard50 / rideMinutes).toStringAsFixed(2)}), 급회전 ${rideTurn50}건 '
        '(분당 ${(rideTurn50 / rideMinutes).toStringAsFixed(2)})');
    b.writeln('사고 폴더 넘어짐 판정(50Hz): $accidentFalls50');
    b.writeln('사고 폴더 넘어짐 판정(3.3Hz): $accidentFalls3');
    // ignore: avoid_print
    print(b);

    // 정상 주행에서 넘어짐(-30점)으로 오인하는 일은 없어야 한다.
    expect(rideFalls50.every((c) => c == 0), isTrue, reason: '50Hz 정상 주행 넘어짐 오탐');
    expect(rideFalls3.every((c) => c == 0), isTrue, reason: '3.3Hz 정상 주행 넘어짐 오탐');
    // 넘어짐 시험은 폴더마다 최소 1회는 잡혀야 한다.
    for (final e in accidentFalls50.entries.where((e) => e.key.contains('overturn'))) {
      expect(e.value, greaterThanOrEqualTo(1), reason: '${e.key} 넘어짐 미검출(50Hz)');
    }
  }, skip: skip);

  test('임계값 스윕: 정상 주행에서 분당 몇 건이나 잡히는가', () {
    final riding = dir!
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('Riding'))
        .map(_load)
        .toList();
    final minutes = riding.fold<double>(0, (m, d) => m + d.length / 50 / 60);
    final b = StringBuffer(
        '\n정상 주행 ${minutes.toStringAsFixed(1)}분 — 임계값별 분당 건수 / 10분 주행 시 예상 감점\n');

    b.writeln('[급가속·급정거 Δ진행축(g)]   50Hz 분당 | 3.3Hz 분당');
    for (final th in [0.4, 0.5, 0.6, 0.7, 0.8, 1.0, 1.2]) {
      int n50 = 0, n3 = 0;
      for (final d in riding) {
        final t = DetectorThresholds(hardAccelDeltaG: th, hardBrakeDeltaG: th);
        final a = _replay(d, thresholds: t);
        final l = _replay(d, step: 15, thresholds: t);
        n50 += a.c(DrivingEventType.hardAccel) + a.c(DrivingEventType.hardBrake);
        n3 += l.c(DrivingEventType.hardAccel) + l.c(DrivingEventType.hardBrake);
      }
      b.writeln('  ${th.toStringAsFixed(1)}g   ${(n50 / minutes).toStringAsFixed(2).padLeft(6)} (10분 -${(n50 / minutes * 10 * 5).toStringAsFixed(0)}점)'
          ' | ${(n3 / minutes).toStringAsFixed(2).padLeft(6)} (10분 -${(n3 / minutes * 10 * 5).toStringAsFixed(0)}점)');
    }

    b.writeln('[급회전 yaw(°/s)]');
    for (final th in [120.0, 130.0, 140.0, 150.0, 175.0, 200.0]) {
      int n50 = 0, n3 = 0;
      for (final d in riding) {
        final t = DetectorThresholds(sharpTurnDps: th);
        n50 += _replay(d, thresholds: t).c(DrivingEventType.sharpTurn);
        n3 += _replay(d, step: 15, thresholds: t).c(DrivingEventType.sharpTurn);
      }
      b.writeln('  ${th.toStringAsFixed(0)}°/s   ${(n50 / minutes).toStringAsFixed(2).padLeft(6)} | ${(n3 / minutes).toStringAsFixed(2).padLeft(6)}');
    }
    // ignore: avoid_print
    print(b);
  }, skip: skip);
}
