import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/responsive.dart';
import 'home_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _checking = false;
  bool _resending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // 이 화면은 "OOO로 인증 메일을 보냈어요"라고 안내하는데, 회원가입 직후가
    // 아니라 나중에 로그인해서 이 화면에 다시 도착한 경우(예: 미인증 계정으로
    // 재로그인)에는 실제로는 아무 메일도 보내지 않은 상태였어요. 그래서 화면이
    // 뜰 때 한 번은 항상 발송을 시도해서 안내 문구와 실제 동작을 맞춥니다.
    _sendInitialVerification();
  }

  Future<void> _sendInitialVerification() async {
    try {
      await AuthService.sendEmailVerification();
    } catch (e) {
      // ignore: avoid_print
      print('Initial email verification send failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_sendErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) _startCooldown();
    }
  }

  String _sendErrorMessage(Object error) {
    if (error is FirebaseAuthException && error.code == 'too-many-requests') {
      return '인증 메일 요청이 너무 잦아요. 5~10분 정도 후에 다시 시도해주세요.';
    }
    return '인증 메일 발송에 실패했어요. 잠시 후 다시 시도해주세요.';
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown -= 1;
        if (_resendCooldown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await AuthService.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증 메일을 다시 보냈어요. 메일함(스팸함 포함)을 확인해주세요.')),
      );
      _startCooldown();
    } catch (e) {
      // ignore: avoid_print
      print('Resend email verification failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_sendErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _checkVerified() async {
    setState(() => _checking = true);
    try {
      await AuthService.reloadCurrentUser();
      if (!mounted) return;
      if (AuthService.isEmailVerified) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아직 인증이 확인되지 않았어요. 메일의 링크를 먼저 눌러주세요.')),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  // 건너뛰기를 누르면 바로 넘어가지 않고, 이메일 인증이 왜 필요한지 먼저 안내해요.
  Future<void> _skip() async {
    final skip = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('이메일 인증을 먼저 하는 게 좋아요', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          '이메일 인증은 안전한 거래를 위한 기본 절차예요.\n\n'
          '· 인증을 마치지 않으면 경매 등록·입찰 같은 거래 기능을 이용할 수 없어요.\n'
          '· 비밀번호 재설정 등 계정 보호에도 꼭 필요해요.\n'
          '· 지금 메일함에서 링크만 누르면 바로 끝나요.',
          style: TextStyle(height: 1.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF94A3B8)),
            child: const Text('그래도 나중에', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16305C)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('지금 인증할게요', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (skip != true || !mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ResponsiveContentBounds(
              maxWidth: context.responsive(phone: double.infinity, tablet: 420.0),
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFEEF3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mark_email_unread_rounded, size: 40, color: Color(0xFFE11D48)),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    '이메일 인증을 완료해주세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${widget.email}\n으로 인증 메일을 보냈어요. 메일함(스팸함 포함)에서\n링크를 눌러 인증을 완료해주세요.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _checking ? null : _checkVerified,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16305C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _checking ? '확인 중...' : '인증 완료 확인',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: (_resending || _resendCooldown > 0) ? null : _resend,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF16305C),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _resendCooldown > 0 ? '인증 메일 재발송 (${_resendCooldown}초)' : '인증 메일 재발송',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: _skip,
                    child: const Text(
                      '나중에 인증할게요',
                      style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
