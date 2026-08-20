import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../routes/app_routes.dart';

/// 주행 종료 후 보여주는 안전점수 결과 화면.
/// TODO(Firestore): 지금은 더미 데이터. events 컬렉션에서 세션 집계값 받아와서
/// score / avgSpeedKmh / hardBrakeCount / hardAccelCount 채우면 됨.
class ScoreResultScreen extends StatelessWidget {
  const ScoreResultScreen({
    super.key,
    this.score = 85,
    this.maxScore = 100,
    this.avgSpeedKmh = 65,
    this.hardBrakeCount = 0,
    this.hardAccelCount = 1,
  });

  final int score;
  final int maxScore;
  final int avgSpeedKmh;
  final int hardBrakeCount;
  final int hardAccelCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.brandGradientStart,
              Color(0xFFF3F0FA), // 아래로 갈수록 연한 라벤더로 페이드
            ],
            stops: [0.0, 0.45],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Color(0xFFF4C430), size: 44),
                    const SizedBox(height: 12),
                    Text(
                      '안전점수',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    _ScoreBox(score: score, maxScore: maxScore),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _StatChip(
                            label: '평균 속도',
                            value: '$avgSpeedKmh km/h',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatChip(
                            label: '급제동',
                            value: '$hardBrakeCount회',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatChip(
                            label: '급가속',
                            value: '$hardAccelCount회',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.brandGradientStart,
                              AppColors.brandGradientEnd,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            onTap: () {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                AppRoutes.home,
                                (route) => false,
                              );
                            },
                            child: const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.home, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    '메인으로',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({required this.score, required this.maxScore});

  final int score;
  final int maxScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF6DE), // 연한 크림색
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: const Color(0xFFF0E4A8)),
      ),
      child: Column(
        children: [
          Text(
            '$score',
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8B6F1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '/ $maxScore점',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          const Icon(Icons.trending_up, size: 16, color: AppColors.brandGradientStart),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}