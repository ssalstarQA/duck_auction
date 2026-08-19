import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import 'deep_link.dart';

/// 동일 계정 중복(동시) 로그인 방지 — "마지막에 로그인한 기기만 유지" 방식이에요.
///
/// 동작:
///  1) 로그인/앱 시작 시 이 기기만의 세션 id를 하나 만들어 users/{uid}.activeSessionId에
///     기록하고, 그 문서를 실시간 구독합니다.
///  2) 다른 기기에서 같은 계정으로 로그인하면 activeSessionId가 그 기기 값으로 덮여요.
///  3) 구독 중이던 이전 기기는 "내 세션 id와 다르다"를 감지해 자동 로그아웃되고,
///     안내 팝업을 띄운 뒤 로그인 화면으로 보냅니다.
///
/// 서버(별도 함수) 없이 Firestore 규칙(본인 문서 읽기/쓰기)만으로 동작해요.
class SessionGuard {
  SessionGuard._();
  static final SessionGuard instance = SessionGuard._();

  String? _uid;
  String? _sessionId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  bool _evicting = false;

  static String _newSessionId() {
    final rnd = Random();
    return '${DateTime.now().microsecondsSinceEpoch}-${rnd.nextInt(1 << 31)}';
  }

  /// 로그인된 사용자에 대해 세션 감시를 시작해요. main()의 authStateChanges에서 호출.
  Future<void> start(String uid) async {
    // 같은 계정으로 이미 감시 중이면 중복 시작하지 않아요.
    if (_uid == uid && _sub != null) return;
    await stop();

    _uid = uid;
    final sessionId = _newSessionId();
    _sessionId = sessionId;

    // 이 기기를 '현재 활성 세션'으로 등록해요(다른 기기 세션을 덮어씀).
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'activeSessionId': sessionId,
        'activeSessionAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // 기록 실패해도 앱 사용은 막지 않아요(다음 시작 때 다시 시도).
    }

    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (_evicting) return;
      final data = snap.data();
      if (data == null) return;
      final active = data['activeSessionId'] as String?;
      // 다른 기기가 새 세션으로 덮어썼으면(내 세션과 다름) 이 기기는 로그아웃.
      if (active != null && active.isNotEmpty && active != _sessionId) {
        _evicting = true;
        unawaited(_evict());
      }
    });
  }

  /// 로그아웃/사용자 없음일 때 감시를 정리해요.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _uid = null;
    _sessionId = null;
    _evicting = false;
  }

  Future<void> _evict() async {
    await _sub?.cancel();
    _sub = null;
    _uid = null;
    _sessionId = null;

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    final ctx = DeepLink.navigatorKey.currentContext;
    if (ctx != null) {
      await showDialog<void>(
        context: ctx,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('다른 기기에서 로그인됐어요', style: TextStyle(fontWeight: FontWeight.w900)),
          content: const Text(
            '같은 계정으로 다른 기기에서 로그인되어, 이 기기에서는 로그아웃됐어요.\n'
            '본인이 아니라면 비밀번호를 변경해 주세요.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }

    final nav = DeepLink.navigatorKey.currentState;
    nav?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    _evicting = false;
  }
}
