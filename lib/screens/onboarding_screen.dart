import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// TODO: components/OnboardingScreen.tsx 내용 보고 실제 UI로 채우기 (Figma 참고)
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(
          'OnboardingScreen (구현 예정)',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
