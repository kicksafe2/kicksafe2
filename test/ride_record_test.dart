import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kicksafe/services/ride_service.dart';

Map<String, dynamic> _doc({
  String status = 'completed',
  int score = 92,
  DateTime? start,
  int seconds = 600,
  double meters = 2340,
}) =>
    {
      'uid': 'u1',
      'status': status,
      'totalScore': score,
      'origin': '서울 중구 세종대로 110',
      'destination': '서울 종로구 종로 1',
      'durationSeconds': seconds,
      'distanceMeters': meters,
      'avgSpeedKmh': 14.2,
      'maxSpeedKmh': 21.0,
      if (start != null) 'startTime': Timestamp.fromDate(start),
    };

void main() {
  test('Firestore 문서가 기록 카드에 맞는 값으로 변환된다', () {
    final r = RideRecord.fromMap('a', _doc(start: DateTime(2026, 11, 11, 9)));
    final item = r.toHistoryItem();
    expect(item.from, '서울 중구 세종대로 110');
    expect(item.to, '서울 종로구 종로 1');
    expect(item.score, 92);
    expect(item.duration, '10분');
    expect(item.distanceKm, 2.3);
    expect(item.date, '11월 11일');
  });

  test('1시간 이상은 시간+분으로, 1분 미만은 1분으로 표시', () {
    expect(RideRecord.fromMap('a', _doc(seconds: 3900)).durationText, '1시간 5분');
    expect(RideRecord.fromMap('a', _doc(seconds: 20)).durationText, '1분');
  });

  test('값이 비어 있어도 죽지 않고 기본값을 쓴다', () {
    final r = RideRecord.fromMap('a', {'status': 'completed'});
    expect(r.origin, '출발지');
    expect(r.destination, '도착지');
    expect(r.score, 0);
    expect(r.distanceKm, 0);
  });

  test('완료된 주행만 최신순으로 정렬된다', () {
    final list = RideService.sortedCompleted([
      ('old', _doc(start: DateTime(2026, 11, 1))),
      ('driving', _doc(status: 'driving', start: DateTime(2026, 11, 20))),
      ('new', _doc(start: DateTime(2026, 11, 10))),
    ]);
    expect(list.map((r) => r.id), ['new', 'old']);
  });

  test('서버 시간이 아직 없는 방금 끝난 기록은 맨 위로', () {
    final list = RideService.sortedCompleted([
      ('past', _doc(start: DateTime(2026, 11, 10))),
      ('justNow', _doc()), // startTime 없음(쓰기 대기 중)
    ]);
    expect(list.first.id, 'justNow');
  });
}
