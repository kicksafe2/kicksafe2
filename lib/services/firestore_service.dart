import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 사용자 생성 또는 업데이트
  Future<void> setUser(String userId, String name) async {
    await _db.collection('users').doc(userId).set({
      'name': name,
      'score': 100,
      'level': 1,
      'discountRate': 5,
    });
  }

  // 사용자 정보 가져오기
  Future<Map<String, dynamic>?> getUser(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data();
  }

  // 점수 업데이트
  Future<void> updateScore(String userId, int penalty) async {
    await _db.collection('users').doc(userId).update({
      'score': FieldValue.increment(penalty),
    });
  }

  // 이벤트 기록
  Future<void> addEvent(String userId, String type, int penalty) async {
    await _db.collection('events').add({
      'userId': userId,
      'type': type,
      'penalty': penalty,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // 실시간 점수 스트림
  Stream<DocumentSnapshot> getUserStream(String userId) {
    return _db.collection('users').doc(userId).snapshots();
  }
}