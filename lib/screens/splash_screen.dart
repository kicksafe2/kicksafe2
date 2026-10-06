import 'dart:async';

import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../services/local_auth_service.dart';
import '../widgets/kicksafe_ui.dart';

/// Figma 디자인(SplashScreen.tsx): 보라색 그라데이션 배경에 로고 + 바운스 점 3개.
/// 2.5초 뒤 온보딩을 이미 끝냈으면 로그인, 아니면 온보딩으로 이동한다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2500), _next);
  }

  Future<void> _next() async {
    final done = await LocalAuthService.hasCompletedOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      done ? AppRoutes.login : AppRoutes.onboarding,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bounce.dispose();
    super.dispose();
  }

  /// delay(0~1) 만큼 위상이 어긋난 바운스 점
  Widget _dot(double delay) {
    return AnimatedBuilder(
      animation: _bounce,
      builder: (context, _) {
        final t = (_bounce.value - delay) % 1.0;
        final lift = t < 0.5 ? (t / 0.5) : (1 - (t - 0.5) / 0.5);
        return Transform.translate(
          offset: Offset(0, -10 * Curves.easeInOut.transform(lift)),
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        );
      },
    );
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
            colors: [KsColors.purple600, KsColors.purple700, KsColors.indigo800],
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (context, v, child) => Opacity(opacity: v, child: child),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KsGlowShield(size: 128),
                const SizedBox(height: 24),
                const Text(
                  'kicksafe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [_dot(0), _dot(0.15), _dot(0.3)],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
