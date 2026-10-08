import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 배지 달성 지도 화면.
/// TODO(Firestore): 지금은 더미 데이터. users 컬렉션에서 보유 배지 수를 받아와서
/// _currentBadgeCount 채우면 됨.
class BadgeMapScreen extends StatelessWidget {
  const BadgeMapScreen({super.key});

  static const _currentBadgeCount = 5;

  static const List<_Milestone> _milestones = [
    _Milestone(badges: 5, benefit: '10% 할인', detail: '다음 5회 주행 시 10% 할인 적용'),
    _Milestone(badges: 10, benefit: '20% 할인', detail: '다음 10회 주행 시 20% 할인 적용'),
    _Milestone(badges: 20, benefit: '25% 할인', detail: '다음 10회 주행 시 25% 할인 적용'),
    _Milestone(badges: 30, benefit: '30% 할인', detail: '다음 15회 주행 시 30% 할인 적용'),
    _Milestone(
      badges: 40,
      benefit: '35% 할인 + 특별 배지',
      detail: '다음 15회 주행 시 35% 할인 + 실버 배지',
    ),
    _Milestone(
      badges: 50,
      benefit: '40% 할인 + VIP 혜택',
      detail: '다음 20회 주행 시 40% 할인 + 골드 배지',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // 다음 목표: 아직 달성 안 한 마일스톤 중 가장 작은 것
    final nextMilestone = _milestones.firstWhere(
      (m) => m.badges > _currentBadgeCount,
      orElse: () => _milestones.last,
    );
    final remaining = (nextMilestone.badges - _currentBadgeCount).clamp(0, nextMilestone.badges);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _Header(context: context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _CurrentBadgeCard(count: _currentBadgeCount),
                const SizedBox(height: 16),
                _NextGoalCard(
                  remaining: remaining,
                  current: _currentBadgeCount,
                  target: nextMilestone.badges,
                ),
                const SizedBox(height: 20),
                for (int i = 0; i < _milestones.length; i++)
                  _MilestoneRow(
                    milestone: _milestones[i],
                    currentBadgeCount: _currentBadgeCount,
                    isLast: i == _milestones.length - 1,
                  ),
                const SizedBox(height: 16),
                const _BottomBanner(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Milestone {
  const _Milestone({
    required this.badges,
    required this.benefit,
    required this.detail,
  });

  final int badges;
  final String benefit;
  final String detail;
}

class _Header extends StatelessWidget {
  const _Header({required this.context});

  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16,
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
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Text(
            '배지 달성 지도',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentBadgeCard extends StatelessWidget {
  const _CurrentBadgeCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final medalCount = count.clamp(0, 5);
    return Column(
      children: [
        const Text(
          '현재 보유 배지',
          style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: AppColors.brandGradientStart,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            medalCount,
            (_) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Icon(Icons.emoji_events, color: Color(0xFFF4C430), size: 22),
            ),
          ),
        ),
      ],
    );
  }
}

class _NextGoalCard extends StatelessWidget {
  const _NextGoalCard({
    required this.remaining,
    required this.current,
    required this.target,
  });

  final int remaining;
  final int current;
  final int target;

  @override
  Widget build(BuildContext context) {
    final progress = target == 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brandGradientStart.withOpacity(0.08),
            AppColors.brandGradientEnd.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.brandGradientStart.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '다음 목표까지',
            style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$remaining개',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandGradientStart,
                ),
              ),
              Text(
                '$current / $target',
                style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.muted,
              valueColor: const AlwaysStoppedAnimation(AppColors.brandGradientStart),
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.milestone,
    required this.currentBadgeCount,
    required this.isLast,
  });

  final _Milestone milestone;
  final int currentBadgeCount;
  final bool isLast;

  bool get _achieved => currentBadgeCount >= milestone.badges;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _StageIcon(achieved: _achieved),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _achieved
                      ? AppColors.brandGradientStart.withOpacity(0.06)
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.card_giftcard, size: 16, color: AppColors.brandGradientStart),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '배지 ${milestone.badges}개',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.foreground,
                            ),
                          ),
                        ),
                        if (_achieved)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Text(
                              '달성',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      milestone.benefit,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandGradientStart,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      milestone.detail,
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                    ),
                    if (!_achieved) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '진행도',
                            style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                          ),
                          Text(
                            '$currentBadgeCount / ${milestone.badges}',
                            style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: LinearProgressIndicator(
                          value: (currentBadgeCount / milestone.badges).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: AppColors.muted,
                          valueColor: const AlwaysStoppedAnimation(AppColors.brandGradientStart),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageIcon extends StatelessWidget {
  const _StageIcon({required this.achieved});

  final bool achieved;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: achieved ? AppColors.brandGradientStart : AppColors.card,
        border: Border.all(
          color: achieved ? AppColors.brandGradientStart : AppColors.border,
          width: 2,
        ),
      ),
      child: Icon(
        achieved ? Icons.check : Icons.lock,
        size: 16,
        color: achieved ? Colors.white : AppColors.mutedForeground,
      ),
    );
  }
}

class _BottomBanner extends StatelessWidget {
  const _BottomBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.brandGradientStart,
            AppColors.brandGradientEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const Column(
        children: [
          Icon(Icons.military_tech, color: Colors.white, size: 28),
          SizedBox(height: 8),
          Text(
            '안전 운전으로 더 많은 혜택을!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            '90점 이상의 안전 점수를 받으면 배지를 획득할 수 있습니다',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}