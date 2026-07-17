import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._();

  static const String _keepLoginKey = 'keepLogin';
  static const String _saveEmailKey = 'saveEmail';
  static const String _savedEmailKey = 'savedEmail';

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  static Future<bool> isKeepLoginEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // 개발/웹 실행에서 체크박스 저장값이 날아가도 Firebase 로그인 세션이 있으면 유지되게 기본값을 true로 둡니다.
    return prefs.getBool(_keepLoginKey) ?? true;
  }

  static Future<void> setKeepLoginEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepLoginKey, enabled);
  }

  static Future<bool> isSaveEmailEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_saveEmailKey) ?? false;
  }

  static Future<String> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedEmailKey) ?? '';
  }

  static Future<void> setSavedEmail({
    required bool enabled,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_saveEmailKey, enabled);

    if (enabled) {
      await prefs.setString(_savedEmailKey, email.trim());
    } else {
      await prefs.remove(_savedEmailKey);
    }
  }

  static Future<UserCredential> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = credential.user;

    if (user == null) {
      throw Exception('회원가입에 실패했습니다. 다시 시도해주세요.');
    }

    await user.updateDisplayName(nickname.trim());

    // Firestore 저장이 실패해도 회원가입 자체는 성공 처리한다.
    // 지금 단계에서는 Auth 연결 확인이 우선이라 Firestore 권한/DB 설정 때문에 가입이 막히지 않게 처리.
    try {
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email.trim(),
        'nickname': nickname.trim(),
        'phoneVerified': false,
        'role': 'user',
        'penaltyCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ignore: avoid_print
      print('Firestore user save failed: $e');
    }

    return credential;
  }

  static Future<UserCredential> signIn({
    required String email,
    required String password,
    bool keepLogin = false,
  }) async {
    if (kIsWeb) {
      try {
        // Chrome을 껐다 켜도 유지되도록 항상 LOCAL persistence를 사용합니다.
        await _auth.setPersistence(Persistence.LOCAL);
      } catch (_) {}
    }

    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    await setKeepLoginEnabled(true);

    return credential;
  }

  static Future<void> signOut() async {
    await setKeepLoginEnabled(false);
    await _auth.signOut();
  }
}
