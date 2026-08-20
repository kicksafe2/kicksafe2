import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 지난 주행 기록 목록 화면.
/// TODO(Firestore): 지금은 더미 데이터. events 컬렉션에서 사용자의
/// 세션별 기록(출발지/도착지/점수/소요시간/거리/날짜)을 가져와 채우면 됨.
class HistoryScreen extends StatelessWidget {
   HistoryScreen({super.key, List<RideHistoryItem>? rides})
      : rides = rides ?? _dummyRides;

  final List<RideHistoryItem> rides;

  static final List<RideHistoryItem> _dummyRides = [
    RideHistoryItem(
      from: '서울 강남',
      to: '인천 송도',
      score: 98,
      duration: '2시간 15분',
      distanceKm: 45.2,
      date: '2026-05-18',
    ),
    RideHistoryItem(
      from: '분당',
      to: '강남',
      score: 92,
      duration: '45분',
      distanceKm: 18.5,
      date: '2026-05-17',
    ),
    RideHistoryItem(
      from: '수원',
      to: '서울',
      score: 95,
      duration: '1시간 20분',
      distanceKm: 35.8,
      date: '2026-05-16',
    ),
    RideHistoryItem(
      from: '서울 종로',
      to: '성남',
      score: 88,
      duration: '55분',
      distanceKm: 22.3,
      date: '2026-05-15',
    ),
    RideHistoryItem(
      from: '일산',
      to: '서울 강북',
      score: 94,
      duration: '1시간 10분',
      distanceKm: 28.7,
      date: '2026-05-14',
    ),
  ];

  int get _totalRides => rides.length;

  double get _averageScore =>
      rides.isEmpty ? 0 : rides.map((r) => r.score).reduce((a, b) => a + b) / rides.length;

  int get _safeRideCount => rides.where((r) => r.score >= 90).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _Header(
            totalRides: _totalRides,
            averageScore: _averageScore,
            safeRideCount: _safeRideCount,
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rides.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _RideCard(ride: rides[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.totalRides,
    required this.averageScore,
    required this.safeRideCount,
  });

  final int totalRides;
  final double averageScore;
  final int safeRideCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brandGradientStart,
            AppColors.brandGradientEnd,
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text(
                '주행 기록',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _HeaderStat(value: '$totalRides', label: '중 주행'),
              ),
              Expanded(
                child: _HeaderStat(
                  value: averageScore.round().toString(),
                  label: '평균 점수',
                ),
              ),
              Expanded(
                child: _HeaderStat(value: '$safeRideCount', label: '90점 이상'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class RideHistoryItem {
  const RideHistoryItem({
    required this.from,
    required this.to,
    required this.score,
    required this.duration,
    required this.distanceKm,
    required this.date,
  });

  final String from;
  final String to;
  final int score;
  final String duration;
  final double distanceKm;
  final String date;
}

class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride});

  final RideHistoryItem ride;

  Color get _scoreColor {
    if (ride.score >= 90) return const Color(0xFF16A34A); // green
    if (ride.score >= 80) return const Color(0xFFCA8A04); // yellow/amber
    return AppColors.destructive; // red
  }

  Color get _scoreBg {
    if (ride.score >= 90) return const Color(0xFFE7F6EC);
    if (ride.score >= 80) return const Color(0xFFFDF3D8);
    return const Color(0xFFFBE7EA);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LocationRow(text: ride.from, isStart: true),
                const SizedBox(height: 4),
                _LocationRow(text: ride.to, isStart: false),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: AppColors.mutedForeground),
                    const SizedBox(width: 4),
                    Text(
                      ride.duration,
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.show_chart, size: 14, color: AppColors.mutedForeground),
                    const SizedBox(width: 4),
                    Text(
                      '${ride.distanceKm}km',
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      ride.date,
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _scoreBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              '${ride.score}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _scoreColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.text, required this.isStart});

  final String text;
  final bool isStart;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.location_on,
          size: 16,
          color: isStart ? AppColors.brandGradientStart : AppColors.mutedForeground,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isStart ? FontWeight.w600 : FontWeight.w400,
            color: AppColors.foreground,
          ),
        ),
      ],
    );
  }
}