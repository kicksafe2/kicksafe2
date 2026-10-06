import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 서버 없이 기기에 저장하는 임시 계정/온보딩 저장소.
/// 원본 디자인(React)의 localStorage 동작을 그대로 옮긴 것으로,
/// 나중에 Firebase Auth(feature/firebase-auth)로 교체할 예정.
class LocalAuthService {
  LocalAuthService._();

  static const _usersKey = 'users';
  static const usernameKey = 'username'; // 홈 화면이 읽는 표시용 이름
  static const onboardingKey = 'hasCompletedOnboarding';

  static String _hash(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  static Future<List<Map<String, dynamic>>> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usersKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(onboardingKey) ?? false;
  }

  static Future<void> completeOnboarding(String displayName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(usernameKey, displayName);
    await prefs.setBool(onboardingKey, true);
  }

  static Future<bool> isUsernameTaken(String username) async {
    final users = await _loadUsers();
    return users.any((u) => u['username'] == username);
  }

  static Future<void> register({
    required String name,
    required String username,
    required String password,
    required String phone,
    required String email,
    required String birthdate,
    required String address,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final users = await _loadUsers();
    users.add({
      'name': name,
      'username': username,
      'passwordHash': _hash(password),
      'phone': phone,
      'email': email,
      'birthdate': birthdate,
      'address': address,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_usersKey, jsonEncode(users));
    await prefs.setString(usernameKey, name);
  }

  /// 아이디/비밀번호가 맞으면 true. 맞으면 홈 화면에 표시할 이름도 저장한다.
  static Future<bool> login(String username, String password) async {
    final users = await _loadUsers();
    final hash = _hash(password);
    for (final u in users) {
      if (u['username'] == username && u['passwordHash'] == hash) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(usernameKey, (u['name'] as String?) ?? username);
        return true;
      }
    }
    return false;
  }
}
