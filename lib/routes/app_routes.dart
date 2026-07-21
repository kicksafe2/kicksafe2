import 'package:flutter/material.dart';

import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/home_screen.dart';
import '../screens/helmet_verification_screen.dart';
import '../screens/map_screen.dart';
import '../screens/driving_blocked_screen.dart';
import '../screens/score_result_screen.dart';
import '../screens/reward_banner_screen.dart';
import '../screens/history_screen.dart';
import '../screens/account_screen.dart';
import '../screens/badge_map_screen.dart';

/// routes.ts의 path들을 그대로 옮긴 라우트 이름
class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const helmetVerification = '/helmet-verification';
  static const map = '/map';
  static const drivingBlocked = '/driving-blocked';
  static const scoreResult = '/score-result';
  static const rewardBanner = '/reward-banner';
  static const history = '/history';
  static const account = '/account';
  static const badgeMap = '/badge-map';

  static Map<String, WidgetBuilder> get routes => {
        splash: (_) => const SplashScreen(),
        onboarding: (_) => const OnboardingScreen(),
        login: (_) => const LoginScreen(),
        signup: (_) => const SignupScreen(),
        home: (_) => const HomeScreen(),
        helmetVerification: (_) => const HelmetVerificationScreen(),
        map: (_) => const MapScreen(),
        drivingBlocked: (_) => const DrivingBlockedScreen(),
        scoreResult: (_) => const ScoreResultScreen(),
        rewardBanner: (_) => const RewardBannerScreen(),
        history: (_) => const HistoryScreen(),
        account: (_) => const AccountScreen(),
        badgeMap: (_) => const BadgeMapScreen(),
      };
}
