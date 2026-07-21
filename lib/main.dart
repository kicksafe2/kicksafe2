import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KickSafe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,           // 기존 theme: ThemeData(...) 이 부분을 이걸로 교체
      initialRoute: AppRoutes.splash,  // 이 두 줄 추가
      routes: AppRoutes.routes,
    );
  }
}