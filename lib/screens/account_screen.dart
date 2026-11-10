import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../routes/app_routes.dart';

/// 내 계정 화면.
/// TODO(Firestore): 지금은 더미 데이터. users 컬렉션에서 닉네임/보유 배지 수 등
/// 실제 값 받아와서 _AccountData 채우면 됨.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  static const _userName = '사용자';
  static const _badgeCount = 0;
  static const _hasBenefits = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _Header(context: context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ProfileCard(userName: _userName),
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.emoji_events,
                  title: '내 배지',
                  trailing: _LinkText(
                    label: '달성 지도',
                    onTap: () {
                      Navigator.of(context).pushNamed(AppRoutes.badgeMap);
                    },
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.brandGradientStart.withOpacity(0.12),
                          AppColors.brandGradientEnd.withOpacity(0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$_badgeCount',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandGradientEnd,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '개 보유',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.lock,
                  title: '보안',
                  child: _ListRow(
                    label: '비밀번호 변경',
                    onTap: () {
                      // TODO: 비밀번호 변경 화면/다이얼로그 연결
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.card_giftcard,
                  title: '받은 혜택',
                  child: _hasBenefits
                      ? const SizedBox.shrink() // TODO: 혜택 리스트
                      : const _EmptyBenefits(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
            '내 계정',
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.userName});

  final String userName;

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
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.brandGradientStart,
                  AppColors.brandGradientEnd,
                ],
              ),
            ),
            child: const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'kicksafe 회원',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.edit, size: 18, color: AppColors.mutedForeground),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.brandGradientStart),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.brandGradientStart,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.brandGradientStart),
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 14, color: AppColors.foreground),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBenefits extends StatelessWidget {
  const _EmptyBenefits();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.card_giftcard, size: 36, color: AppColors.mutedForeground),
        const SizedBox(height: 8),
        const Text(
          '아직 받은 혜택이 없습니다',
          style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 4),
        Text(
          '배지를 모아보세요!',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.brandGradientStart,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
