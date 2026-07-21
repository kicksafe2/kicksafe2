import 'package:flutter/material.dart';
import 'screen/ble_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/firestore_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase 초기화 실패: $e');
  }

  // 앱을 먼저 띄운다 (Firestore가 느리거나 실패해도 화면은 뜨도록)
  runApp(const MyApp());

  // Firestore 테스트는 백그라운드로 (await로 앱 시작을 막지 않음)
  FirestoreService()
      .setUser('testUser1', '홍길동')
      .then((_) => print('Firestore 연동 완료!'))
      .catchError((e) => print('Firestore 쓰기 실패: $e'));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KickSafe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const BleScreen()
    );
  }
}