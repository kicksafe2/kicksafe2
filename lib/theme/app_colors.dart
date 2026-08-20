import 'package:flutter/material.dart';

/// Figma(theme.css)의 shadcn 테마 값을 Flutter 색상으로 옮긴 것.
/// oklch(...) 로 정의된 값들은 근사 hex로 변환했어요.
/// 실제 화면 만들면서 Figma 스샷과 눈으로 비교해 미세 조정하면 됩니다.
class AppColors {
  AppColors._();

  // ---- Light mode (기본) ----
  static const background = Color(0xFFFFFFFF);
  static const foreground = Color(0xFF0A0A0A); // oklch(0.145 0 0)

  static const card = Color(0xFFFFFFFF);
  static const cardForeground = Color(0xFF0A0A0A);

  static const primary = Color(0xFF030213);
  static const primaryForeground = Color(0xFFFFFFFF);

  static const secondary = Color(0xFFF1F1F5); // oklch(0.95 0.0058 264.53) 근사
  static const secondaryForeground = Color(0xFF030213);

  static const muted = Color(0xFFECECF0);
  static const mutedForeground = Color(0xFF717182);

  static const accent = Color(0xFFE9EBEF);
  static const accentForeground = Color(0xFF030213);

  static const destructive = Color(0xFFD4183D);
  static const destructiveForeground = Color(0xFFFFFFFF);

  static const border = Color(0x1A000000); // rgba(0,0,0,0.1)
  static const inputBackground = Color(0xFFF3F3F5);
  static const switchBackground = Color(0xFFCBCED4);

  static const ring = Color(0xFFB5B5B5); // oklch(0.708 0 0) 근사
  // ---- Brand gradient (로그인/홈/기록/점수결과 등 상단·버튼에 공통 사용) ----
  static const brandGradientStart = Color(0xFF7C3AED); // violet-600
  static const brandGradientEnd = Color(0xFF4C1D95); // purple-900
  // ---- Chart colors (필요할 때만 사용) ----
  static const chart1 = Color(0xFFE07B39);
  static const chart2 = Color(0xFF2A9D8F);
  static const chart3 = Color(0xFF264653);
  static const chart4 = Color(0xFFE9C46A);
  static const chart5 = Color(0xFFF4A261);
}
