import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 탈퇴 후 같은 이메일로 바로 재가입하는 것을 막을 때(쿨다운이 아직 남아있을 때)
/// 던지는 예외입니다. [remainingDays]는 재가입까지 남은 일수(최소 1일)입니다.
class RejoinBlockedException implements Exception {
  final int remainingDays;
  const RejoinBlockedException(this.remainingDays);
}

/// 이미 다른 사용자가 쓰고 있는 닉네임으로 가입/변경을 시도할 때 던지는 예외입니다.
/// UI에서 이 예외를 잡아 "이미 사용 중인 닉네임" 안내를 보여주면 됩니다.
class NicknameTakenException implements Exception {
  const NicknameTakenException();
}

class AuthService {
  AuthService._();

  static const String _keepLoginKey = 'keepLogin';
  static const String _saveEmailKey = 'saveEmail';
  static const String _savedEmailKey = 'savedEmail';
  static const String _pushNotificationKey = 'pushNotificationEnabled';
  static const String _marketingNotificationKey = 'marketingNotificationEnabled';

  /// 탈퇴한 이메일로 재가입을 막는 기간입니다. 이 값만 바꾸면 정책을 조정할 수 있어요.
  static const Duration rejoinCooldown = Duration(days: 30);
  static const String _withdrawnAccountsCollection = 'withdrawnAccounts';

  /// 닉네임 중복을 막기 위한 "예약" 컬렉션입니다. 문서 ID로 정규화된 닉네임을
  /// 쓰고, 값으로 소유자 uid를 저장합니다. (이메일 재가입 제한이
  /// withdrawnAccounts/{email} 을 쓰는 것과 같은 방식이에요.)
  static const String _nicknamesCollection = 'nicknames';

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static User? get currentUser => _auth.currentUser;

  static bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// 휴대폰 인증 여부는 Firebase Auth에 실제로 연결된 전화번호가 있는지로
  /// 판단합니다(별도 Firestore 플래그에만 의존하면 동기화가 어긋날 수 있어요).
  static bool get isPhoneVerified => _auth.currentUser?.phoneNumber != null;

  static Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  /// 서버에 저장된 최신 인증 상태를 다시 받아옵니다(이메일 인증 링크를
  /// 클릭한 직후에는 클라이언트가 들고 있는 emailVerified 값이 갱신되지
  /// 않으므로, 확인 버튼을 누를 때 이 메서드로 새로고침해야 합니다).
  static Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  static Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    await user.sendEmailVerification();
  }

  /// 한국 휴대폰 번호(예: 010-1234-5678, 01012345678)를 국제 표준 형식
  /// (+821012345678)으로 바꿔줍니다. 형식이 이상하면 null을 돌려줍니다.
  static String? formatKoreanPhoneToE164(String rawInput) {
    final digits = rawInput.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    final withoutLeadingZero = digits.startsWith('0') ? digits.substring(1) : digits;
    if (withoutLeadingZero.length < 8 || withoutLeadingZero.length > 11) return null;
    return '+82$withoutLeadingZero';
  }

  /// 현재 로그인된 계정에 휴대폰 번호로 인증 문자를 보내고, 인증번호 확인에
  /// 쓸 [ConfirmationResult]를 돌려줍니다. 이미 로그인되어 있는 이메일 계정에
  /// "연결(link)"하는 방식이라, 완료되면 같은 계정으로 로그인 시 전화번호도
  /// 함께 확인된 상태가 됩니다.
  static Future<ConfirmationResult> sendPhoneVerificationCode(String e164PhoneNumber) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요해요.');
    }
    // 웹에서는 reCAPTCHA 확인이 필요한데, verifier를 따로 안 만들어 넘기면
    // firebase_auth가 화면에 보이지 않는 기본 reCAPTCHA를 자동으로 준비해줘요.
    // (직접 RecaptchaVerifier를 만들어보려고 했는데, 이 패키지 버전에서는
    // 생성자 인자 타입이 안 맞아 컴파일이 깨져서 다시 기본값으로 되돌렸어요.)
    return user.linkWithPhoneNumber(e164PhoneNumber);
  }

  /// 문자로 받은 인증번호를 확인해서 휴대폰 번호 연결을 완료합니다.
  static Future<void> confirmPhoneVerificationCode(
    ConfirmationResult confirmationResult,
    String smsCode,
  ) async {
    await confirmationResult.confirm(smsCode);

    // 프로필 화면 등에서 참고할 수 있도록 Firestore에도 인증 상태를 같이
    // 남겨둡니다(실패해도 인증 자체는 이미 완료된 상태라 가입/이용은 막지 않아요).
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _db.collection('users').doc(user.uid).set({
          'phoneVerified': true,
          'phoneNumber': user.phoneNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        // Firestore 기록 실패는 인증 완료 자체를 막지 않습니다.
      }
    }
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

  /// 닉네임을 중복 판정용 키로 정규화합니다: 앞뒤 공백 제거, 소문자화,
  /// 내부 연속 공백을 하나로. (예: "Duck  Lover" 와 "duck lover" 를 같은
  /// 닉네임으로 취급해 대소문자·띄어쓰기만 다른 사칭을 막아요.)
  static String normalizeNickname(String nickname) =>
      nickname.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// 닉네임이 지금 사용 가능한지 미리 확인합니다(입력 즉시 검사용).
  /// true = 사용 가능, false = 이미 다른 사람이 사용 중.
  /// [excludeUid]는 본인 닉네임 변경 시 자기 자신을 제외하기 위한 값입니다.
  /// 읽기 자체가 실패하면(권한/네트워크) 확인 불가로 보고 true(통과)를 돌려줘,
  /// 이 기능 때문에 정상 가입/수정이 막히지 않게 합니다. 실제 중복 방지는
  /// [reserveNickname]의 트랜잭션이 원자적으로 보장합니다.
  static Future<bool> isNicknameAvailable(String nickname, {String? excludeUid}) async {
    final key = normalizeNickname(nickname);
    if (key.isEmpty) return false;
    try {
      final doc = await _db.collection(_nicknamesCollection).doc(key).get();
      if (!doc.exists) return true;
      final owner = doc.data()?['uid'] as String?;
      return owner == null || owner == excludeUid;
    } catch (_) {
      return true;
    }
  }

  /// 닉네임을 [uid]에게 "원자적으로" 예약합니다. 트랜잭션 안에서 먼저 읽고,
  /// 다른 사람이 이미 차지하고 있으면 [NicknameTakenException]을 던집니다.
  /// [previousNickname]을 넘기면(닉네임 변경 시) 이전 닉네임 예약을 함께
  /// 반납해서 다른 사용자가 다시 쓸 수 있게 합니다.
  ///
  /// 트랜잭션 규칙상 모든 읽기를 쓰기보다 먼저 수행해야 하므로, 신규/기존 키를
  /// 먼저 모두 get 한 뒤에 set/delete 합니다.
  static Future<void> reserveNickname({
    required String uid,
    required String nickname,
    String? previousNickname,
  }) async {
    final newKey = normalizeNickname(nickname);
    if (newKey.isEmpty) {
      throw ArgumentError('닉네임이 비어 있어요.');
    }
    final oldKey = (previousNickname == null || previousNickname.trim().isEmpty)
        ? null
        : normalizeNickname(previousNickname);

    await _db.runTransaction((tx) async {
      final newRef = _db.collection(_nicknamesCollection).doc(newKey);
      final oldRef = (oldKey != null && oldKey != newKey)
          ? _db.collection(_nicknamesCollection).doc(oldKey)
          : null;

      // 읽기 먼저(모두).
      final newSnap = await tx.get(newRef);
      final oldSnap = oldRef == null ? null : await tx.get(oldRef);

      // 다른 사람이 이미 쓰는 닉네임이면 차단.
      if (newSnap.exists && (newSnap.data()?['uid'] as String?) != uid) {
        throw const NicknameTakenException();
      }

      // 쓰기(모두).
      tx.set(newRef, {
        'uid': uid,
        'nickname': nickname.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 이전 닉네임 예약이 "내 것"일 때만 반납(남의 것은 건드리지 않음).
      if (oldRef != null &&
          oldSnap != null &&
          oldSnap.exists &&
          (oldSnap.data()?['uid'] as String?) == uid) {
        tx.delete(oldRef);
      }
    });
  }

  static Future<UserCredential> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    // 닉네임 중복이면 계정을 만들기 전에 먼저 막아, 불필요한 계정 생성을 피합니다.
    // (읽기 실패 시엔 통과하고, 아래 예약 트랜잭션이 최종적으로 중복을 막습니다.)
    if (!await isNicknameAvailable(nickname)) {
      throw const NicknameTakenException();
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = credential.user;

    if (user == null) {
      throw Exception('회원가입에 실패했습니다. 다시 시도해주세요.');
    }

    // 탈퇴 후 재가입 제한: 계정 생성 직후(=인증된 상태)에 이 이메일이 최근에
    // 탈퇴한 이력이 있는지 확인합니다. 아직 쿨다운 기간이 남아있다면 방금
    // 만든 계정을 되돌리고(rollback) 가입을 막습니다.
    //
    // 조회 자체(Firestore 읽기)가 실패하는 경우(예: 보안 규칙 미설정, 네트워크
    // 문제)는 재가입 제한 기능이 정상 회원가입까지 막아버리지 않도록 그대로
    // 통과시킵니다. 단, 실제로 차단이 확인된 경우의 rollback/예외 발생은 이
    // try/catch 밖에서 처리해 조용히 삼켜지지 않게 합니다.
    var rejoinBlockedDays = 0;
    try {
      final normalizedEmail = _normalizeEmail(email);
      final withdrawnDoc = await _db.collection(_withdrawnAccountsCollection).doc(normalizedEmail).get();
      final withdrawnAt = (withdrawnDoc.data()?['withdrawnAt'] as Timestamp?)?.toDate();

      if (withdrawnDoc.exists && withdrawnAt != null) {
        final elapsed = DateTime.now().difference(withdrawnAt);
        if (elapsed < rejoinCooldown) {
          rejoinBlockedDays = (rejoinCooldown - elapsed).inHours ~/ 24 + 1;
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Rejoin cooldown check failed, allowing signup: $e');
    }

    if (rejoinBlockedDays > 0) {
      await user.delete();
      throw RejoinBlockedException(rejoinBlockedDays);
    }

    // 닉네임을 원자적으로 예약합니다. 위 사전 검사와 이 시점 사이에 다른 사람이
    // 같은 닉네임을 차지한 경쟁 상황이면 방금 만든 계정을 되돌리고 막습니다.
    // 예약 컬렉션 접근이 권한/네트워크로 실패하는 경우(NicknameTaken 이 아닌
    // 예외)에는 가입 자체를 막지 않고 통과시킵니다. (정식 방지에는 보안 규칙이
    // 필요하고, 규칙 적용 후에는 이 트랜잭션이 확실히 동작해요.)
    try {
      await reserveNickname(uid: user.uid, nickname: nickname);
    } on NicknameTakenException {
      await user.delete();
      rethrow;
    } catch (e) {
      // ignore: avoid_print
      print('Nickname reservation failed (allowing signup): $e');
    }

    await user.updateDisplayName(nickname.trim());

    // 인증 메일 발송이 실패해도(네트워크 문제 등) 회원가입 자체는 막지 않고,
    // 이후 인증 화면에서 재발송 버튼으로 다시 시도할 수 있게 한다.
    try {
      await user.sendEmailVerification();
    } catch (e) {
      // ignore: avoid_print
      print('Email verification send failed: $e');
    }

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

  static Future<bool> isPushNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pushNotificationKey) ?? true;
  }

  static Future<void> setPushNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushNotificationKey, enabled);
  }

  static Future<bool> isMarketingNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_marketingNotificationKey) ?? false;
  }

  static Future<void> setMarketingNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_marketingNotificationKey, enabled);
  }

  static Future<void> signOut() async {
    await setKeepLoginEnabled(false);
    await _auth.signOut();
  }

  /// 회원 탈퇴: 이메일/비밀번호 계정은 최근 로그인 상태가 아니면 Firebase가
  /// 삭제를 거부하므로(요구 사항: requires-recent-login), 비밀번호로 먼저
  /// 재인증한 뒤 계정을 삭제합니다.
  ///
  /// 탈퇴 시 다른 사용자와의 거래·채팅 기록이 얽혀있을 수 있는 등록 상품은
  /// 완전히 삭제하지 않고 관리자 신고 처리와 동일하게 '숨김' 처리합니다.
  /// (완전한 연관 데이터 정리는 추후 Cloud Functions로 서버에서 처리하는 것을
  /// 권장합니다.)
  ///
  /// 또한 같은 이메일로 곧바로 재가입하는 것을 막기 위해, 탈퇴 직전에 이
  /// 이메일과 탈퇴 시각을 [_withdrawnAccountsCollection]에 기록합니다.
  /// (signUp에서 이 기록을 확인해 [rejoinCooldown] 기간 동안 재가입을 막습니다.)
  static Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('로그인 정보가 없어요. 다시 로그인 후 시도해주세요.');
    }

    final email = user.email;
    if (password != null && password.trim().isNotEmpty && email != null && email.isNotEmpty) {
      final credential = EmailAuthProvider.credential(email: email, password: password.trim());
      await user.reauthenticateWithCredential(credential);
    }

    final uid = user.uid;

    if (email != null && email.isNotEmpty) {
      try {
        await _db.collection(_withdrawnAccountsCollection).doc(_normalizeEmail(email)).set({
          'email': _normalizeEmail(email),
          'lastUid': uid,
          'withdrawnAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // 재가입 제한 기록이 실패해도 탈퇴 자체를 막지는 않습니다.
        // (다만 이 경우 재가입 쿨다운이 적용되지 않을 수 있어요.)
      }
    }

    try {
      // products 문서의 판매자 필드명은 'sellerId'입니다(ProductItem.toFirestore/fromFirestore 기준).
      final myProducts = await _db.collection('products').where('sellerId', isEqualTo: uid).get();
      for (final doc in myProducts.docs) {
        await doc.reference.set({
          'status': 'hidden',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // 상품 숨김 처리가 실패해도 탈퇴 자체는 계속 진행합니다.
    }

    try {
      await _db.collection('users').doc(uid).delete();
    } catch (_) {
      // 프로필 문서 삭제 실패도 탈퇴를 막지 않습니다.
    }

    await user.delete();

    await setKeepLoginEnabled(false);
    await setSavedEmail(enabled: false, email: '');
  }
}
