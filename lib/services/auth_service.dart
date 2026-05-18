import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 현재 로그인된 유저
  User? get currentUser => _auth.currentUser;

  // 회원가입
  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print('회원가입 오류: $e');
      return null;
    }
  }

  // 로그인
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print('로그인 오류: $e');
      return null;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }
}