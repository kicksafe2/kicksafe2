import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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
      // TODO: 홈 화면 테스트용 임시 설정. 테스트 끝나면 AppRoutes.splash로 되돌릴 것.
      initialRoute: AppRoutes.home,
      routes: AppRoutes.routes,
    );
  }
}
