import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import 'auth_service.dart';
import 'deep_link.dart';

/// 푸시 알림(FCM) 권한 요청, 토큰 저장/정리, 수신 처리를 담당합니다.
///
/// 웹에서는 별도의 VAPID 키와 서비스워커(web/firebase-messaging-sw.js) 설정이
/// 더 필요해서(현재 미설정) 지금은 모바일(Android/iOS)에서만 동작하도록
/// kIsWeb으로 막아뒀습니다. 나중에 웹 푸시도 지원하려면 그 설정을 먼저 하고
/// 여기 초기화 로직을 확장하면 됩니다.
///
/// 실제 발송(누구에게 어떤 알림을 언제 보낼지)은 Cloud Functions
/// (functions/index.js)에서 처리합니다. 이 서비스는 "이 기기가 알림을 받을
/// 준비가 되어 있다"는 상태를 서버(Firestore users/{uid})에 알려주고,
/// 도착한 알림을 화면에 보여주는 클라이언트 쪽 역할만 합니다.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  bool _initialized = false;
  String? _currentToken;

  // 포그라운드 알림 몰림 방지용: 짧은 시간에 도착한 알림을 모아 한 번만 안내해요.
  int _fgPending = 0;
  String? _fgLastText;
  Timer? _fgTimer;

  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final pushEnabled = await AuthService.isPushNotificationEnabled();
    if (!pushEnabled) return;

    _initialized = true;

    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 사용자가 알림 권한을 거부해도 앱 이용 자체는 계속할 수 있어야 하므로
      // 여기서 흐름을 막지 않고 조용히 끝냅니다.
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final token = await messaging.getToken();
      if (token != null) {
        await _saveToken(token);
      }

      messaging.onTokenRefresh.listen(_saveToken);

      // 앱을 켜놓고 보고 있을 때(포그라운드) 도착한 알림은 시스템 알림함에
      // 자동으로 뜨지 않아서, 화면 위에 짧게 안내(SnackBar)로 대신 보여줍니다.
      FirebaseMessaging.onMessage.listen(_showForegroundMessage);

      // 알림을 눌러서 앱을 연 경우, 알림에 담긴 정보로 관련 화면까지 이동시킵니다.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // 앱이 완전히 꺼져 있다가 알림을 눌러서 처음 켜진 경우도 같은 방식으로 처리합니다.
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      // 알림 등록이 실패해도(권한 거부, 기기 미지원 등) 앱 이용 자체를 막지 않습니다.
      // ignore: avoid_print
      print('Push notification init failed: $e');
    }
  }

  bool _consentPrompted = false;

  /// 앱을 열었거나 가입한 직후, 알림 권한이 없으면 "중요 알림(낙찰·입찰·결제·
  /// 배송 상태 변경)을 못 받을 수 있다"고 안내하고 동의를 받아요. 동의하면
  /// 신규 사용자는 OS 권한 요청창을 띄우고, 이미 거부한 사용자는 설정에서
  /// 켜도록 안내해요. 자꾸 뜨지 않게 앱 실행당 한 번만 물어봐요.
  Future<void> ensureNotificationConsent(BuildContext context) async {
    if (kIsWeb || _consentPrompted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _consentPrompted = true;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      final status = settings.authorizationStatus;

      // 이미 허용된 상태면 토큰 등록만 확실히 해두고 끝내요.
      if (status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional) {
        _initialized = false;
        await initialize();
        return;
      }

      if (!context.mounted) return;
      final agree = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('알림을 켜면 놓치지 않아요', style: TextStyle(fontWeight: FontWeight.w900)),
          content: const Text(
            '알림을 허용하지 않으면 낙찰·입찰·결제·배송 상태 변경 같은 중요한 소식을 '
            '제때 받지 못할 수 있어요.\n\n지금 알림을 켤까요?',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('나중에'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('알림 켜기'),
            ),
          ],
        ),
      );
      if (agree != true) return;

      if (status == AuthorizationStatus.notDetermined) {
        // 신규(아직 물어본 적 없음): OS 권한 요청창을 띄워요.
        final result = await messaging.requestPermission(alert: true, badge: true, sound: true);
        if (result.authorizationStatus == AuthorizationStatus.authorized ||
            result.authorizationStatus == AuthorizationStatus.provisional) {
          _initialized = false;
          await initialize();
        } else if (context.mounted) {
          _showManualEnableGuide(context);
        }
      } else {
        // 이미 거부한 상태: OS가 권한창을 다시 안 띄우므로 설정에서 켜도록 안내해요.
        if (context.mounted) _showManualEnableGuide(context);
      }
    } catch (_) {
      // 실패해도 앱 이용은 계속돼요.
    }
  }

  void _showManualEnableGuide(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('설정에서 알림을 켜주세요', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          '휴대폰 설정 > 앱 > 덕옥션 > 알림 에서 알림을 켜면 중요한 소식을 받을 수 있어요.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToken(String token) async {
    _currentToken = token;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'pushEnabled': true,
      }, SetOptions(merge: true));
    } catch (_) {
      // 저장 실패는 조용히 무시합니다(다음 토큰 갱신 때 다시 시도돼요).
    }
  }

  /// 설정 화면에서 푸시 알림 스위치를 껐을 때 호출합니다.
  Future<void> disable() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'pushEnabled': false,
        if (_currentToken != null) 'fcmTokens': FieldValue.arrayRemove([_currentToken]),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// 설정 화면에서 푸시 알림 스위치를 다시 켰을 때 호출합니다.
  Future<void> enable() async {
    _initialized = false;
    await initialize();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'pushEnabled': true,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// 로그아웃/회원탈퇴 직전에 호출해서, 이 기기 토큰을 서버 기록에서 지웁니다.
  /// (로그아웃 이후에는 currentUser가 null이 되어 uid를 알 수 없으므로 반드시
  /// signOut()/deleteAccount() 호출 "전"에 실행해야 합니다.)
  Future<void> removeTokenOnLogout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _currentToken == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayRemove([_currentToken]),
      }, SetOptions(merge: true));
    } catch (_) {}
    _initialized = false;
  }

  void _showForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null && body == null) return;

    // 짧은 시간(0.9초)에 여러 알림이 도착하면 SnackBar가 줄줄이 뜨지 않게 모아서
    // 한 번만 보여줘요. 1건이면 그대로, 여러 건이면 "새 알림 N개"로 합쳐요.
    _fgPending++;
    _fgLastText = [if (title != null) title, if (body != null) body].join(' - ');
    _fgTimer?.cancel();
    _fgTimer = Timer(const Duration(milliseconds: 900), _flushForegroundMessages);
  }

  void _flushForegroundMessages() {
    final count = _fgPending;
    _fgPending = 0;
    if (count <= 0) return;
    final context = DeepLink.navigatorKey.currentState?.overlay?.context;
    if (context == null) return;

    final text = count == 1
        ? (_fgLastText ?? '새 알림이 도착했어요.')
        : '새 알림 $count개가 도착했어요.';
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// 알림 데이터(functions/index.js에서 실어 보내는 productId/roomId 등)를 보고
  /// 해당 상품 상세 화면 또는 채팅방으로 바로 이동시킵니다.
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    final data = message.data;
    final navigator = DeepLink.navigatorKey.currentState;
    if (navigator == null) return;

    // 유찰 알림(입찰자 없음 / 결제 기한 만료)은 판매자를 '내 경매 관리'로 보내
    // 유찰된 경매를 바로 '새로 등록' 또는 '경매 연장' 하게 해줍니다.
    if (data['type'] == 'auction_failed') {
      navigator.push(
        MaterialPageRoute(builder: (_) => const MyAuctionManageScreen()),
      );
      return;
    }

    final productId = data['productId'];
    if (productId == null || (productId as String).isEmpty) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where(FieldPath.documentId, isEqualTo: productId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return;
      final product = ProductItem.fromFirestore(snapshot.docs.first);

      if (data['type'] == 'chat_message') {
        final roomId = data['roomId'];
        navigator.push(
          MaterialPageRoute(
            builder: (_) => SellerChatScreen(product: product, roomIdOverride: roomId),
          ),
        );
      } else {
        navigator.push(
          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
        );
      }
    } catch (e) {
      // 이동 실패는 조용히 무시합니다(삭제된 상품, 네트워크 문제 등).
      // ignore: avoid_print
      print('Notification tap navigation failed: $e');
    }
  }
}
