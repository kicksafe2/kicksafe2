import 'package:flutter/material.dart';

import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/home_screen.dart';
import '../screens/helmet_verification_screen.dart';
import '../screens/map_screen.dart';
import '../screens/driving_blocked_screen.dart';
import '../screens/driving_screen.dart';
import '../screens/score_result_screen.dart';
import '../screens/reward_banner_screen.dart';
import '../screens/history_route.dart';
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
  static const driving = '/driving';
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
        driving: (context) {
          // 지도 화면이 arguments: DrivingScreenArgs(경로·안내) 로 넘겨준다.
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is DrivingScreenArgs) return DrivingScreen(args: args);
          return const Scaffold(body: Center(child: Text('경로 정보가 없어요. 지도에서 다시 시작해주세요')));
        },
        scoreResult: (context) {
          // 주행 화면이 arguments: {'score', 'avgSpeedKmh', 'hardBrakeCount', 'hardAccelCount',
          // 'penaltyLines', 'notice'} 로 넘겨준 값을 점수 결과 화면에 전달
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map && args['score'] is int) {
            int intOf(String k, int fallback) => args[k] is num ? (args[k] as num).round() : fallback;
            return ScoreResultScreen(
              score: args['score'] as int,
              avgSpeedKmh: intOf('avgSpeedKmh', 0),
              hardBrakeCount: intOf('hardBrakeCount', 0),
              hardAccelCount: intOf('hardAccelCount', 0),
              penaltyLines: args['penaltyLines'] is List
                  ? List<String>.from(args['penaltyLines'] as List)
                  : const [],
              notice: args['notice'] as String?,
            );
          }
          return const ScoreResultScreen();
        },
        rewardBanner: (_) => const RewardBannerScreen(),
        history: (_) => const HistoryRoute(),
        account: (_) => const AccountScreen(),
        badgeMap: (_) => const BadgeMapScreen(),
      };
}
