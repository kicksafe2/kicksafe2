import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'ble_test_screen.dart';   // ← 추가

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (kDebugMode) print('Firebase 초기화 실패: $e');
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
      home: const BleTestScreen(),   // ← BLE 테스트 중에는 이거
      routes: AppRoutes.routes,
      // initialRoute: AppRoutes.splash,   ← 테스트 끝나면 이 줄 살리고 home 지우기
    );
  }
}