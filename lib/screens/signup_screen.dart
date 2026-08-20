import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// TODO: components/SignupScreen.tsx 내용 보고 실제 UI로 채우기 (Figma 참고)
class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(
          'SignupScreen (구현 예정)',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}