import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kicksafe/scoring/scoring.dart';
import 'package:kicksafe/services/ble_sensor_service.dart';
import 'package:kicksafe/services/sensor_recorder.dart';

SensorReading r({double ax = 0, double az = 1, double gx = 0}) =>
    SensorReading(ax: ax, ay: 0, az: az, gx: gx, gy: 0, gz: 0);

final _t0 = DateTime(2026, 11, 18, 14);
DateTime at(int ms) => _t0.add(Duration(milliseconds: ms));

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('kicksafe_rec_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('센서값이 CSV 로 남고, 첫 샘플이 0ms 기준이다', () async {
    final rec = SensorRecorder(sessionId: 's1', directory: tmp);
    await rec.open();
    rec.addReading(r(ax: 0.5), now: at(0), speedKmh: 12.34);
    rec.addReading(r(ax: -0.25, gx: 200), now: at(20));
    rec.addReading(r(), now: at(40), fake: true);
    await rec.close();

    final lines = File(rec.imuPath!).readAsLinesSync();
    expect(lines.first, 't_ms,ax,ay,az,gx,gy,gz,speed_kmh,source');
    expect(lines[1], '0,0.500,0.000,1.000,0.000,0.000,0.000,12.3,sensor');
    expect(lines[2], '20,-0.250,0.000,1.000,200.000,0.000,0.000,,sensor'); // GPS 속도 없음 → 빈 칸
    expect(lines[3].endsWith(',fake'), isTrue);
    expect(rec.count, 3);
  });

  test('감점 이벤트가 별도 CSV 에 남는다', () async {
    final rec = SensorRecorder(sessionId: 's2', directory: tmp);
    await rec.open();
    rec.addReading(r(), now: at(0));
    final scorer = RideScorer();
    final events = [
      ...scorer.addReading(r(ax: 5, gx: 300), now: at(0)),
      ...scorer.addReading(r(), now: at(1100)),
    ];
    expect(events, hasLength(1));
    rec.addEvent(events.first, now: at(1100));
    await rec.close();

    final lines = File(rec.eventsPath!).readAsLinesSync();
    expect(lines.first, 't_ms,type,penalty,base_penalty,multiplier');
    expect(lines[1], '1100,fall_impact,30,30,1.0');
  });

  test('1초 묶음으로 잘라서 onChunk 로 넘긴다 (stride 8, 값 평탄화)', () async {
    final chunks = <RawChunk>[];
    final rec = SensorRecorder(sessionId: 's3', onChunk: chunks.add);
    // 50Hz 로 2.5초
    for (var i = 0; i < 125; i++) {
      rec.addReading(r(ax: i / 1000), now: at(i * 20), speedKmh: 10);
    }
    await rec.close(now: at(125 * 20));

    expect(chunks.length, 3); // 1초, 1초, 마지막 남은 0.5초
    expect(chunks.map((c) => c.seq), [0, 1, 2]);
    expect(chunks.fold<int>(0, (n, c) => n + c.count), 125);
    expect(chunks.first.tStartMs, 0);
    expect(chunks[1].tStartMs, greaterThanOrEqualTo(1000));

    final m = chunks.first.toMap();
    expect(m['stride'], 8);
    expect(m['count'], chunks.first.count);
    expect((m['data'] as List).length, chunks.first.count * 8);
    // 첫 샘플: [t_ms, ax, ay, az, gx, gy, gz, speed]
    expect((m['data'] as List).take(8).toList(), [0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 10.0]);
  });

  test('중첩 배열이 없다 (Firestore 는 배열 안의 배열을 저장 못 함)', () {
    final rec = SensorRecorder(sessionId: 's4', onChunk: (c) {
      expect((c.toMap()['data'] as List).every((e) => e is num), isTrue);
    });
    rec.addReading(r(), now: at(0));
    rec.addReading(r(), now: at(1500));
  });

  test('폴더가 없어도 만들고, 닫은 뒤 입력은 무시한다', () async {
    final sub = Directory('${tmp.path}/a/b');
    final rec = SensorRecorder(sessionId: 's5', directory: sub);
    await rec.open();
    expect(sub.existsSync(), isTrue);
    rec.addReading(r(), now: at(0));
    await rec.close();
    rec.addReading(r(), now: at(20)); // 닫힌 뒤
    expect(rec.count, 1);
    expect(File(rec.imuPath!).readAsLinesSync().length, 2); // 머리줄 + 1개
  });

  test('저장 폴더를 못 열어도 예외 없이 계속 동작', () async {
    // 파일을 폴더 자리에 만들어 두면 디렉터리 생성이 실패한다.
    final blocker = File('${tmp.path}/blocked')..writeAsStringSync('x');
    final rec = SensorRecorder(sessionId: 's6', directory: Directory('${blocker.path}/sub'));
    await rec.open(); // 던지지 않아야 함
    rec.addReading(r(), now: at(0));
    await rec.close();
    expect(rec.count, 1);
  });

  test('DetectorThresholds.toMap 에 모든 임계값이 들어 있다', () {
    final m = const DetectorThresholds().toMap();
    expect(m.keys, containsAll(['fallImpactG', 'fallGyroDps', 'hardAccelDeltaG', 'hardBrakeDeltaG', 'sharpTurnDps']));
    expect(m['fallImpactG'], 4.0);
  });
}
