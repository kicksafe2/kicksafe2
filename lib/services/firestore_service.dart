import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';


class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // 로컬 버퍼 (메모리에 쌓아두는 곳)
  final List<Map<String, dynamic>> _imuBuffer = [];
  static const int BUFFER_FLUSH_SIZE = 500; // 500개마다 저장

  String get uid {
  final user = _auth.currentUser;
  if (user == null) throw Exception('로그인이 필요합니다');
  return user.uid;
}

  // IMU 데이터 버퍼에 추가
  void addImuToBuffer(String sessionId, {
    required int seq,
    required double ax, required double ay, required double az,
    required double gx, required double gy, required double gz,
  }) {
    _imuBuffer.add({
      'sessionId': sessionId,
      'seq': seq,
      'ax': ax, 'ay': ay, 'az': az,
      'gx': gx, 'gy': gy, 'gz': gz,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // 500개 쌓이면 자동 flush
    if (_imuBuffer.length >= BUFFER_FLUSH_SIZE) {
       unawaited(flushImuBuffer(sessionId));
    }
  }

// 이벤트 기록 (충격, 헬멧 미착용 등)
Future<void> addEvent(String userId, String type, int penalty) async {
  await _db
      .collection('users')
      .doc(userId)
      .collection('events')
      .add({
    'type': type,
    'penalty': penalty,
    'timestamp': FieldValue.serverTimestamp(),
  });
}

// 점수 업데이트
Future<void> updateScore(String userId, int penalty) async {
  await _db.collection('users').doc(userId).update({
    'score': FieldValue.increment(-penalty), // 점수 차감
  });
}
  // 버퍼 → Firestore 배치 저장
  Future<void> flushImuBuffer(String sessionId) async {
    if (_imuBuffer.isEmpty) return;

    // 복사 후 버퍼 즉시 비우기 (새 데이터 계속 받을 수 있게)
    final toSave = List<Map<String, dynamic>>.from(_imuBuffer);
    _imuBuffer.clear();

    // Firestore 배치는 500개 제한 → 500개씩 잘라서 저장
    const batchSize = 500;
    for (int i = 0; i < toSave.length; i += batchSize) {
      final chunk = toSave.sublist(
        i, (i + batchSize).clamp(0, toSave.length),
      );

      final batch = _db.batch();
      for (final log in chunk) {
        final ref = _db
            .collection('imuLogs')
            .doc(sessionId)
            .collection('logs')
            .doc();
        batch.set(ref, log);
      }
      await batch.commit();
      if (kDebugMode) print('IMU 배치 저장 완료: ${chunk.length}개');
    }
  }

  // 세션 종료 시 남은 버퍼 강제 저장
  Future<void> endSession(String sessionId, int finalScore) async {
    // 남은 버퍼 먼저 저장
    await flushImuBuffer(sessionId);

    await _db.collection('sessions').doc(sessionId).update({
      'endTime': FieldValue.serverTimestamp(),
      'totalScore': finalScore,
    });
  }

  // 세션 시작
  Future<String> startSession() async {
    _imuBuffer.clear(); // 새 세션 시작 시 버퍼 초기화
    final ref = await _db.collection('sessions').add({
      'uid': uid,
      'startTime': FieldValue.serverTimestamp(),
      'totalScore': 100,
    });
    return ref.id;
  }

  // 점수 이벤트 저장
  Future<void> saveScoreEvent(String sessionId, String type, int value) async {
    await _db
        .collection('scoreEvents')
        .doc(sessionId)
        .collection('events')
        .add({
      'type': type,
      'value': value,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // 내 세션 목록
  Stream<QuerySnapshot> getSessions() {
    return _db
        .collection('sessions')
        .where('uid', isEqualTo: uid)
        .orderBy('startTime', descending: true)
        .snapshots();
  }
}
