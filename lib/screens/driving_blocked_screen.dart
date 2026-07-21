import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// TODO: components/DrivingBlockedScreen.tsx 내용 보고 실제 UI로 채우기 (Figma 참고)
class DrivingBlockedScreen extends StatelessWidget {
  const DrivingBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(
          'DrivingBlockedScreen (구현 예정)',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
