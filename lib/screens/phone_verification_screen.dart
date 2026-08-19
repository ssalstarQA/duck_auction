import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../utils/responsive.dart';

/// 경매 등록·입찰처럼 실제 거래가 걸린 기능을 쓰려고 할 때 뜨는 휴대폰
/// 본인 확인 화면입니다. 가입이나 로그인 자체를 막지는 않고(구경은 자유롭게),
/// 거래를 시도하는 시점에만 이 화면으로 안내해요. 한 번 인증하면 계정에
/// 전화번호가 연결되어 이후에는 다시 요청하지 않습니다.
class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _codeSent = false;
  bool _sending = false;
  bool _confirming = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  ConfirmationResult? _confirmationResult;
  String? _sentToNumber;
  String? _errorText;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
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

  String _authErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return '휴대폰 번호 형식이 올바르지 않아요.';
      case 'credential-already-in-use':
      case 'account-exists-with-different-credential':
        return '이미 다른 계정에 등록된 번호예요.';
      case 'too-many-requests':
        return '요청이 너무 많아요. 잠시 후 다시 시도해주세요.';
      case 'invalid-verification-code':
        return '인증번호가 올바르지 않아요.';
      case 'code-expired':
        return '인증번호가 만료됐어요. 다시 요청해주세요.';
      case 'captcha-check-failed':
        return '보안 확인에 실패했어요. 새로고침 후 다시 시도해주세요.';
      case 'operation-not-allowed':
        return 'Firebase 콘솔에서 휴대폰 로그인 제공업체가 꺼져 있어요.';
      default:
        // 아직 원인을 못 밝힌 에러 코드예요 — 코드 자체를 화면에 노출해서
        // 다음에 뜰 때 바로 원인을 알 수 있게 합니다.
        return '처리 중 문제가 발생했어요. ($code)';
    }
  }

  Future<void> _sendCode() async {
    final formatted = AuthService.formatKoreanPhoneToE164(_phoneController.text);
    if (formatted == null) {
      setState(() => _errorText = '휴대폰 번호를 정확히 입력해주세요. (예: 010-1234-5678)');
      return;
    }

    setState(() {
      _sending = true;
      _errorText = null;
    });

    try {
      final confirmationResult = await AuthService.sendPhoneVerificationCode(formatted);
      if (!mounted) return;
      setState(() {
        _confirmationResult = confirmationResult;
        _sentToNumber = formatted;
        _codeSent = true;
      });
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증번호를 보냈어요. 문자 메시지를 확인해주세요.')),
      );
    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print('Phone verification send failed: ${e.code} / ${e.message}');
      setState(() => _errorText = _authErrorMessage(e.code));
    } catch (e) {
      // ignore: avoid_print
      print('Phone verification send failed (non-Firebase): $e');
      setState(() => _errorText = '인증번호 발송에 실패했어요. ($e)');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmCode() async {
    final confirmationResult = _confirmationResult;
    final code = _codeController.text.trim();
    if (confirmationResult == null) return;
    if (code.length < 4) {
      setState(() => _errorText = '문자로 받은 인증번호를 입력해주세요.');
      return;
    }

    setState(() {
      _confirming = true;
      _errorText = null;
    });

    try {
      await AuthService.confirmPhoneVerificationCode(confirmationResult, code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('휴대폰 인증이 완료됐어요. 이제 경매 등록/입찰을 이용할 수 있어요.')),
      );
      // 로그인/가입 흐름의 일부가 아니라 거래 시도 중 뜬 화면이라, 홈으로
      // 강제 이동하지 않고 원래 있던 화면으로 되돌아갑니다.
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print('Phone verification confirm failed: ${e.code} / ${e.message}');
      setState(() => _errorText = _authErrorMessage(e.code));
    } catch (e) {
      // ignore: avoid_print
      print('Phone verification confirm failed (non-Firebase): $e');
      setState(() => _errorText = '인증에 실패했어요. ($e)');
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _changeNumber() {
    setState(() {
      _codeSent = false;
      _confirmationResult = null;
      _codeController.clear();
      _errorText = null;
    });
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
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_android_rounded, size: 40, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    _codeSent ? '인증번호를 입력해주세요' : '휴대폰 번호를 인증해주세요',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _codeSent
                        ? '${_sentToNumber ?? ''}\n으로 인증번호를 보냈어요. 문자로 받은\n6자리 숫자를 입력해주세요.'
                        : '경매 등록·입찰 같은 거래 기능은 안전한 이용을 위해\n휴대폰 본인 확인이 필요해요. 가입할 때 한 번만\n확인하면 이후에는 다시 요청하지 않아요.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 26),
                  if (!_codeSent) ...[
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                      decoration: InputDecoration(
                        hintText: '01012345678',
                        prefixIcon: const Icon(Icons.smartphone_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onSubmitted: (_) => _sending ? null : _sendCode(),
                    ),
                  ] else ...[
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 6),
                      decoration: InputDecoration(
                        hintText: '000000',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onSubmitted: (_) => _confirming ? null : _confirmCode(),
                    ),
                  ],
                  if (_errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _codeSent
                          ? (_confirming ? null : _confirmCode)
                          : (_sending ? null : _sendCode),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16305C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _codeSent
                            ? (_confirming ? '확인 중...' : '인증 완료')
                            : (_sending ? '발송 중...' : '인증번호 받기'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_codeSent)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: (_sending || _resendCooldown > 0) ? null : _sendCode,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF16305C),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          _resendCooldown > 0 ? '인증번호 재발송 (${_resendCooldown}초)' : '인증번호 재발송',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  if (_codeSent) ...[
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: _sending || _confirming ? null : _changeNumber,
                      child: const Text(
                        '번호를 다시 입력할게요',
                        style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
