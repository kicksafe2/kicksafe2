import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../scoring/scoring.dart' show DrivingEventTypeLabel, ScoredEvent;
import '../screens/history_screen.dart' show RideHistoryItem;
import 'sensor_recorder.dart' show RawChunk;

/// 저장된 주행 한 건. Firestore `sessions/{sessionId}` 문서와 1:1 이다.
///
/// 센서 원시값(`imuLogs/{sessionId}/logs`)과 점수 이벤트(`scoreEvents/{sessionId}/events`)는
/// 같은 sessionId 로 이어 붙는다. (팀원의 FirestoreService 설계와 같은 구조)
class RideRecord {
  final String id;
  final String origin;
  final String destination;
  final int score;
  final DateTime? startTime;
  final int durationSeconds;
  final double distanceMeters;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final bool simulated;

  const RideRecord({
    required this.id,
    required this.origin,
    required this.destination,
    required this.score,
    required this.startTime,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.simulated,
  });

  factory RideRecord.fromMap(String id, Map<String, dynamic> m) {
    DateTime? time(Object? v) => v is Timestamp ? v.toDate() : null;
    num number(Object? v) => v is num ? v : 0;
    return RideRecord(
      id: id,
      origin: (m['origin'] as String?)?.trim().isNotEmpty == true ? m['origin'] as String : '출발지',
      destination:
          (m['destination'] as String?)?.trim().isNotEmpty == true ? m['destination'] as String : '도착지',
      score: number(m['totalScore']).round(),
      startTime: time(m['startTime']),
      durationSeconds: number(m['durationSeconds']).round(),
      distanceMeters: number(m['distanceMeters']).toDouble(),
      avgSpeedKmh: number(m['avgSpeedKmh']).toDouble(),
      maxSpeedKmh: number(m['maxSpeedKmh']).toDouble(),
      simulated: m['simulated'] == true,
    );
  }

  /// 소요 시간(분). 1분 미만이어도 1분으로 센다.
  int get minutes => max(1, (durationSeconds / 60).round());

  String get durationText {
    final m = minutes;
    return m >= 60 ? '${m ~/ 60}시간 ${m % 60}분' : '$m분';
  }

  /// 거리(km), 소수 1자리.
  double get distanceKm => (distanceMeters / 100).round() / 10;

  String get dateText {
    final t = startTime ?? DateTime.now();
    return '${t.month}월 ${t.day}일';
  }

  RideHistoryItem toHistoryItem() => RideHistoryItem(
        from: origin,
        to: destination,
        score: score,
        duration: durationText,
        distanceKm: distanceKm,
        date: dateText,
      );
}

/// 진행 중인 주행의 핸들. [RideService.start]가 돌려준다.
class RideSession {
  final DocumentReference<Map<String, dynamic>> _ref;
  RideSession._(this._ref);

  /// 센서 데이터(imuLogs/scoreEvents)를 이어 붙일 때 쓰는 세션 ID
  String get id => _ref.id;
}

/// 주행 기록 저장/조회. 저장 위치는 `sessions` 컬렉션.
class RideService {
  RideService._();

  static final _db = FirebaseFirestore.instance;
  static const _saveTimeout = Duration(seconds: 6);

  /// 주행을 시작하며 세션 문서를 만든다. 로그인이 안 되어 있으면 null (기록 안 함).
  /// 네트워크를 기다리지 않는다 — 오프라인이어도 주행은 막히지 않는다.
  static RideSession? start({
    required String origin,
    required String destination,
    required double plannedDistanceMeters,
    required int estimatedMinutes,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final ref = _db.collection('sessions').doc();
    unawaited(ref.set({
      'uid': user.uid,
      'startTime': FieldValue.serverTimestamp(),
      'totalScore': 100,
      'status': 'driving',
      'origin': origin,
      'destination': destination,
      'plannedDistanceMeters': plannedDistanceMeters,
      'estimatedMinutes': estimatedMinutes,
    }).catchError((Object e) => debugPrint('주행 시작 기록 실패: $e')));
    return RideSession._(ref);
  }

  /// 주행을 마치며 결과를 기록한다. 성공하면 null, 실패하면 화면에 보여줄 한국어 메시지.
  static Future<String?> finish(
    RideSession? session, {
    required int score,
    required bool endedEarly,
    required double distanceMeters,
    required int durationSeconds,
    required double avgSpeedKmh,
    required double maxSpeedKmh,
    required bool simulated,
    bool sensorConnected = false,
    int sensorSamples = 0,
    Map<String, int> eventCounts = const {},
    Map<String, int> penaltyBreakdown = const {},
    Map<String, double> thresholds = const {},
    String? rawLogFile,
    int rawSamples = 0,
  }) async {
    if (session == null) return '로그인 정보가 없어 주행 기록을 저장하지 못했어요';
    try {
      await session._ref.set({
        'endTime': FieldValue.serverTimestamp(),
        'totalScore': score,
        'status': 'completed',
        'endedEarly': endedEarly,
        'distanceMeters': distanceMeters,
        'durationSeconds': durationSeconds,
        'avgSpeedKmh': avgSpeedKmh,
        'maxSpeedKmh': maxSpeedKmh,
        'simulated': simulated,
        // 센서 기반 점수 근거(내일 임계값을 조정할 때 어떤 이벤트가 몇 번 나왔는지 확인용)
        'sensorConnected': sensorConnected,
        'sensorSamples': sensorSamples,
        'eventCounts': eventCounts,
        'penaltyBreakdown': penaltyBreakdown,
        // 그 주행에서 쓴 임계값과 원시 기록 위치(임계값을 되짚어 조정할 때 확인용)
        'thresholds': thresholds,
        'rawLogFile': rawLogFile,
        'rawSamples': rawSamples,
      }, SetOptions(merge: true)).timeout(_saveTimeout);
      return null;
    } on TimeoutException {
      // 오프라인: 쓰기는 기기에 대기 중이다가 연결되면 올라간다.
      return '네트워크가 불안정해요. 연결되면 주행 기록이 저장돼요';
    } on FirebaseException catch (e) {
      debugPrint('주행 기록 저장 실패: ${e.code} ${e.message}');
      return switch (e.code) {
        'permission-denied' => '주행 기록 저장 권한이 없어요. Firestore 규칙(firestore.rules)을 게시했는지 확인해주세요',
        'unavailable' => '네트워크가 불안정해요. 연결되면 주행 기록이 저장돼요',
        _ => '주행 기록을 저장하지 못했어요 (${e.code})',
      };
    } catch (e) {
      debugPrint('주행 기록 저장 실패: $e');
      return '주행 기록을 저장하지 못했어요';
    }
  }

  /// 원시 센서값 1초 묶음을 `imuLogs/{sessionId}/logs` 에 저장한다. 기다리지 않는다(주행을 막지 않음).
  static void saveImuChunk(RideSession? session, RawChunk chunk) {
    if (session == null) return;
    final col = _db.collection('imuLogs').doc(session.id).collection('logs');
    unawaited(col.add({...chunk.toMap(), 'createdAt': FieldValue.serverTimestamp()}).catchError((Object err) {
      debugPrint('센서 원시값 저장 실패: $err');
      return col.doc();
    }));
  }

  /// 감점된 이벤트를 `scoreEvents/{sessionId}/events` 에 저장한다. 기다리지 않는다(주행을 막지 않음).
  /// 문서 모양은 팀의 FirestoreService.saveScoreEvent(type, value, timestamp)와 맞췄다.
  static void saveScoreEvents(RideSession? session, List<ScoredEvent> events) {
    if (session == null || events.isEmpty) return;
    final col = _db.collection('scoreEvents').doc(session.id).collection('events');
    for (final e in events) {
      unawaited(col.add({
        'type': e.type.label,
        'value': e.appliedPenalty,
        'basePenalty': e.basePenalty,
        'multiplier': e.multiplier,
        'timestamp': FieldValue.serverTimestamp(),
      }).catchError((Object err) {
        debugPrint('점수 이벤트 저장 실패: $err');
        return col.doc();
      }));
    }
  }

  /// 내 주행 기록(완료된 것만) 실시간 목록. 최신순.
  /// where 한 개만 써서 복합 인덱스 없이 동작하고, 정렬은 앱에서 한다.
  static Stream<List<RideRecord>> watchMyRides() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);
    return _db
        .collection('sessions')
        .where('uid', isEqualTo: user.uid)
        .snapshots()
        .map((snap) => sortedCompleted(
              [for (final d in snap.docs) (d.id, d.data())],
            ));
  }

  /// (문서 ID, 데이터) 목록에서 완료된 주행만 골라 최신순으로 정렬한다.
  @visibleForTesting
  static List<RideRecord> sortedCompleted(List<(String, Map<String, dynamic>)> docs) {
    final rides = [
      for (final (id, data) in docs)
        if (data['status'] == 'completed') RideRecord.fromMap(id, data),
    ];
    // 방금 끝나 서버 시간이 아직 안 찍힌 기록(startTime == null)은 가장 최근으로 본다.
    DateTime when(RideRecord r) => r.startTime ?? DateTime.now();
    rides.sort((a, b) => when(b).compareTo(when(a)));
    return rides;
  }
}
