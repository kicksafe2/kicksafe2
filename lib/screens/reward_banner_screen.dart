import 'package:flutter/material.dart';

import 'badge_map_screen.dart';

/// 리워드 배너 화면.
/// 디자인(Figma)이 배지 달성 지도 화면과 동일하여 BadgeMapScreen을 그대로 사용함.
class RewardBannerScreen extends StatelessWidget {
  const RewardBannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BadgeMapScreen();
  }
}