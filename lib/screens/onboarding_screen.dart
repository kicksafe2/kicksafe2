import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../services/local_auth_service.dart';
import '../widgets/kicksafe_ui.dart';

/// Figma 디자인(OnboardingScreen.tsx): 4단계 온보딩.
/// 1 환영 → 2 배지 혜택 → 3 안전 점수 → 4 이름 입력 후 로그인으로 이동.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  int _step = 1;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await LocalAuthService.completeOnboarding(name);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [KsColors.purple600, KsColors.indigo700, KsColors.purple800],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: switch (_step) {
                          1 => _stepWelcome(),
                          2 => _stepBadges(),
                          3 => _stepScore(),
                          _ => _stepName(),
                        },
                      ),
                    ),
                  ),
                ),
              ),
              _buildIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  // ---- 공용 조각 ----

  Widget _whiteButton(String label, VoidCallback? onTap, {bool arrow = true}) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: 4,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: KsColors.purple600,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (arrow) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: KsColors.purple600, size: 22),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassBox(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _title(String text, {double size = 30}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: size,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
    );
  }

  Widget _subtitle(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: KsColors.purple100, fontSize: 17, height: 1.5),
    );
  }

  // ---- 단계별 화면 ----

  Widget _stepWelcome() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const KsGlowShield(size: 128),
        const SizedBox(height: 32),
        _title('kicksafe에\n오신 것을 환영합니다', size: 34),
        const SizedBox(height: 16),
        _subtitle('안전한 주행을 위한\n스마트 모빌리티 서비스'),
        const SizedBox(height: 48),
        _whiteButton('시작하기', () => setState(() => _step = 2)),
      ],
    );
  }

  Widget _benefitRow(String left, String right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left, style: const TextStyle(color: Colors.white, fontSize: 14)),
          Text(
            right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBadges() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.emoji_events, color: KsColors.yellow300, size: 96),
        const SizedBox(height: 28),
        _title('배지를 모아보세요'),
        const SizedBox(height: 16),
        _subtitle('안전 점수 90점 이상을 받으면\n배지를 획득할 수 있습니다'),
        const SizedBox(height: 28),
        _glassBox(
          Column(
            children: [
              const Text('마일스톤 혜택', style: TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 10),
              _benefitRow('5개 달성', '10% 할인'),
              _benefitRow('10개 달성', '20% 할인'),
              _benefitRow('20개 달성', '25% 할인'),
              const SizedBox(height: 4),
              const Text(
                '배지는 마일스톤 달성 시 리셋됩니다',
                style: TextStyle(color: KsColors.purple200, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        _whiteButton('다음', () => setState(() => _step = 3)),
      ],
    );
  }

  Widget _scoreItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: KsColors.green300, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _stepScore() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.trending_up, color: KsColors.green300, size: 96),
        const SizedBox(height: 28),
        _title('안전 운전 점수'),
        const SizedBox(height: 16),
        _subtitle('주행 후 100점 만점의\n안전 점수를 확인하세요'),
        const SizedBox(height: 28),
        _glassBox(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text('평가 항목', style: TextStyle(color: Colors.white, fontSize: 14)),
              ),
              const SizedBox(height: 14),
              _scoreItem('급제동 횟수'),
              _scoreItem('급가속 횟수'),
              _scoreItem('평균 속도'),
              _scoreItem('안전 운전 시간'),
            ],
          ),
        ),
        const SizedBox(height: 40),
        _whiteButton('다음', () => setState(() => _step = 4)),
      ],
    );
  }

  Widget _stepName() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _title('이름을 입력해주세요')),
        const SizedBox(height: 32),
        const Text('사용자 이름', style: TextStyle(color: Colors.white, fontSize: 17)),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: '이름을 입력하세요',
              hintStyle: const TextStyle(color: KsColors.purple200),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 48),
        _whiteButton(
          '시작하기',
          _nameController.text.trim().isEmpty ? null : _complete,
          arrow: false,
        ),
      ],
    );
  }

  Widget _buildIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var s = 1; s <= 4; s++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: s == _step ? 32 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: s == _step ? Colors.white : Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
        ],
      ),
    );
  }
}
