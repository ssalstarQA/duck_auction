import 'package:flutter/material.dart';

import 'email_login_screen.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _goTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _showPreparing(BuildContext context, String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$provider 로그인은 연동 준비 중이에요. 현재는 이메일 로그인을 이용해주세요.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFF8FAFC),
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 18),
                  Center(
                    child: Image.asset(
                      'assets/image/image/main_title.png',
                      width: 178,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    '가장 빠른 굿즈 경매',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      height: 1.25,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '찾던 굿즈를 더 쉽고 안전하게\n덕옥션에서 경매로 만나보세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 34),
                  _SocialLoginButton(
                    text: '카카오로 계속하기',
                    iconText: 'K',
                    backgroundColor: const Color(0xFFFEE500),
                    foregroundColor: const Color(0xFF191919),
                    onTap: () => _showPreparing(context, '카카오'),
                  ),
                  const SizedBox(height: 10),
                  _SocialLoginButton(
                    text: '네이버로 계속하기',
                    iconText: 'N',
                    backgroundColor: const Color(0xFF03C75A),
                    foregroundColor: Colors.white,
                    onTap: () => _showPreparing(context, '네이버'),
                  ),
                  const SizedBox(height: 10),
                  _SocialLoginButton(
                    text: 'Google로 계속하기',
                    iconText: 'G',
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF111827),
                    borderColor: const Color(0xFFE2E8F0),
                    onTap: () => _showPreparing(context, 'Google'),
                  ),
                  const SizedBox(height: 10),
                  _SocialLoginButton(
                    text: 'Apple로 계속하기',
                    iconText: '',
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    onTap: () => _showPreparing(context, 'Apple'),
                  ),
                  const SizedBox(height: 22),
                  const _DividerWithText(text: '또는'),
                  const SizedBox(height: 18),
                  _EmailActionButton(
                    text: '이메일로 로그인',
                    onTap: () => _goTo(context, const EmailLoginScreen()),
                  ),
                  const SizedBox(height: 10),
                  _EmailActionButton(
                    text: '이메일로 회원가입',
                    onTap: () => _goTo(context, const SignupScreen()),
                    filled: false,
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                      );
                    },
                    child: const Text(
                      '게스트로 둘러보기',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '회원가입 시 서비스 이용약관, 개인정보 수집 및 이용,\n안전거래 정책에 동의하게 됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  final String text;
  final String iconText;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _SocialLoginButton({
    required this.text,
    required this.iconText,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor ?? backgroundColor),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: foregroundColor.withOpacity(backgroundColor == Colors.white ? 0.04 : 0.10),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  iconText,
                  style: TextStyle(
                    fontSize: iconText == '' ? 20 : 15,
                    fontWeight: FontWeight.w900,
                    color: foregroundColor,
                  ),
                ),
              ),
            ),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool filled;

  const _EmailActionButton({
    required this.text,
    required this.onTap,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: filled
          ? FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF334155),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onTap,
              child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF334155),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onTap,
              child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
    );
  }
}

class _DividerWithText extends StatelessWidget {
  final String text;

  const _DividerWithText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
      ],
    );
  }
}
