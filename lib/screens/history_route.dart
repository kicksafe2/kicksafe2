import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/ride_service.dart';
import 'history_screen.dart';

/// `/history` 라우트: Firestore 에서 내 주행 기록을 실시간으로 받아 [HistoryScreen]에 넘긴다.
/// (화면 자체는 기록 목록만 받아 그리는 순수 UI로 두었다.)
class HistoryRoute extends StatefulWidget {
  const HistoryRoute({super.key});

  @override
  State<HistoryRoute> createState() => _HistoryRouteState();
}

class _HistoryRouteState extends State<HistoryRoute> {
  late final Stream<List<RideRecord>> _rides = RideService.watchMyRides();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RideRecord>>(
      stream: _rides,
      builder: (context, snap) {
        if (snap.hasError) {
          final e = snap.error;
          final message = e is FirebaseException && e.code == 'permission-denied'
              ? '주행 기록을 불러올 권한이 없어요.\nFirestore 규칙(firestore.rules)을 게시했는지 확인해주세요'
              : '주행 기록을 불러오지 못했어요.\n네트워크 연결을 확인해주세요';
          return Scaffold(
            appBar: AppBar(title: const Text('주행 기록')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(message, textAlign: TextAlign.center),
              ),
            ),
          );
        }
        final rides = [for (final r in snap.data ?? const <RideRecord>[]) r.toHistoryItem()];
        return HistoryScreen(rides: rides);
      },
    );
  }
}
