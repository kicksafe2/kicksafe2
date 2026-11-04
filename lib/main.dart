import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'config/app_config.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase 초기화 실패: $e');
  }

  try {
    await FlutterNaverMap().init(
      clientId: AppConfig.naverMapClientId,
      onAuthFailed: (e) => print('네이버 지도 인증 실패: $e'),
    );
  } catch (e) {
    print('네이버 지도 초기화 실패: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KickSafe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}
