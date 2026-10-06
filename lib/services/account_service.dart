import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'onboarding_store.dart';

/// 화면에 그대로 보여줄 수 있는 한국어 메시지를 담은 예외.
class AccountException implements Exception {
  final String message;
  const AccountException(this.message);
  @override
  String toString() => message;
}

/// 회원가입/로그인 + 프로필 저장.
///
/// - 비밀번호는 Firebase Auth만 보관한다 (Firestore에는 저장하지 않음).
/// - `users/{uid}`        : 이름·아이디·연락처·생년월일·주소 등 프로필 (+ 점수/레벨 기본값)
/// - `usernames/{아이디}` : 아이디 중복 방지 + 아이디로 로그인할 때 이메일을 찾기 위한 색인
class AccountService {
  AccountService._();

  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static final _usernamePattern = RegExp(r'^[A-Za-z0-9_]+$');

  static String? validateUsername(String username) {
    if (!_usernamePattern.hasMatch(username)) {
      return '아이디는 영문, 숫자, _ 만 사용할 수 있습니다';
    }
    return null;
  }

  static String _key(String username) => username.trim().toLowerCase();

  /// 아이디 중복확인. 사용 가능하면 true.
  static Future<bool> isUsernameAvailable(String username) async {
    final doc = await _db.collection('usernames').doc(_key(username)).get();
    return !doc.exists;
  }

  /// Auth 계정 생성 → Firestore에 프로필/아이디 색인 저장(트랜잭션).
  /// 저장에 실패하면 방금 만든 Auth 계정을 지워 반쪽짜리 가입이 남지 않게 한다.
  static Future<void> signUp({
    required String name,
    required String username,
    required String password,
    required String phone,
    required String email,
    required String birthdate,
    required String address,
  }) async {
    final cred = await _createAuthUser(email, password);
    final user = cred.user!;

    try {
      final usernameRef = _db.collection('usernames').doc(_key(username));
      final userRef = _db.collection('users').doc(user.uid);

      await _db.runTransaction((tx) async {
        final existing = await tx.get(usernameRef);
        if (existing.exists) {
          throw const AccountException('이미 사용 중인 아이디입니다');
        }
        tx.set(usernameRef, {'uid': user.uid, 'email': email});
        tx.set(userRef, {
          'name': name,
          'username': username.trim(),
          'email': email,
          'phone': phone,
          'birthdate': birthdate,
          'address': address,
          'createdAt': FieldValue.serverTimestamp(),
          // 기존 FirestoreService(setUser)와 같은 기본값
          'score': 100,
          'level': 1,
          'discountRate': 5,
        });
      });
      await user.updateDisplayName(name);
      await OnboardingStore.saveDisplayName(name);
    } catch (e) {
      await user.delete().catchError((_) {});
      if (e is AccountException) rethrow;
      throw const AccountException('회원 정보를 저장하지 못했습니다. 잠시 후 다시 시도해주세요');
    }
  }

  static Future<UserCredential> _createAuthUser(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AccountException(switch (e.code) {
        'email-already-in-use' => '이미 가입된 이메일입니다',
        'invalid-email' => '이메일 형식이 올바르지 않습니다',
        'weak-password' => '비밀번호는 6자 이상이어야 합니다',
        'network-request-failed' => '네트워크 연결을 확인해주세요',
        'operation-not-allowed' => 'Firebase에서 이메일/비밀번호 로그인이 꺼져 있습니다',
        _ => '회원가입에 실패했습니다 (${e.code})',
      });
    }
  }

  /// [idOrEmail]에 '@'가 있으면 이메일로, 없으면 아이디로 간주해 로그인한다.
  static Future<void> signIn(String idOrEmail, String password) async {
    final input = idOrEmail.trim();
    try {
      final email = input.contains('@') ? input : await _emailForUsername(input);
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);

      final profile = await _db.collection('users').doc(cred.user!.uid).get();
      final name = (profile.data()?['name'] as String?) ?? cred.user!.displayName ?? input;
      await OnboardingStore.saveDisplayName(name);
    } on FirebaseAuthException catch (e) {
      throw AccountException(switch (e.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'invalid-email' =>
          '아이디 또는 비밀번호가 올바르지 않습니다',
        'too-many-requests' => '로그인 시도가 너무 많습니다. 잠시 후 다시 시도해주세요',
        'user-disabled' => '사용이 중지된 계정입니다',
        'network-request-failed' => '네트워크 연결을 확인해주세요',
        _ => '로그인에 실패했습니다 (${e.code})',
      });
    }
  }

  static Future<String> _emailForUsername(String username) async {
    if (validateUsername(username) != null) {
      throw const AccountException('아이디 또는 비밀번호가 올바르지 않습니다');
    }
    final doc = await _db.collection('usernames').doc(_key(username)).get();
    final email = doc.data()?['email'] as String?;
    if (email == null) {
      throw const AccountException('아이디 또는 비밀번호가 올바르지 않습니다');
    }
    return email;
  }

  static Future<void> signOut() => _auth.signOut();

  static User? get currentUser => _auth.currentUser;
}
