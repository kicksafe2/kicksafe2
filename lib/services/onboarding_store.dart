import 'package:shared_preferences/shared_preferences.dart';

/// 온보딩 완료 여부와 홈 화면에 표시할 이름을 기기에 저장한다.
/// (계정 정보 자체는 Firebase Auth/Firestore에 저장 — AccountService 참고)
class OnboardingStore {
  OnboardingStore._();

  static const usernameKey = 'username'; // 홈 화면이 읽는 표시용 이름
  static const _onboardingKey = 'hasCompletedOnboarding';

  static Future<bool> hasCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  static Future<void> complete(String displayName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(usernameKey, displayName);
    await prefs.setBool(_onboardingKey, true);
  }

  static Future<void> saveDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(usernameKey, name);
  }
}
