import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../utils/responsive.dart';
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

  // 카카오 로그인: SDK로 로그인 → accessToken을 Cloud Function(kakaoLogin)에 보내
  // Firebase 커스텀 토큰을 받아 signInWithCustomToken으로 로그인해요.
  Future<void> _kakaoLogin(BuildContext context) async {
    try {
      OAuthToken token;
      if (await isKakaoTalkInstalled()) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
        } catch (_) {
          // 카카오톡 로그인 취소/실패 시 카카오계정 로그인으로 폴백
          token = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
      final res = await FirebaseFunctions.instance
          .httpsCallable('kakaoLogin')
          .call<Map<String, dynamic>>({'accessToken': token.accessToken});
      final firebaseToken = res.data['token'] as String;
      await FirebaseAuth.instance.signInWithCustomToken(firebaseToken);
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카카오 로그인에 실패했어요. 다시 시도해주세요.')),
      );
    }
  }

  // 네이버 로그인: SDK로 로그인 → accessToken을 Cloud Function(naverLogin)에 보내
  // Firebase 커스텀 토큰을 받아 signInWithCustomToken으로 로그인해요.
  Future<void> _naverLogin(BuildContext context) async {
    try {
      await FlutterNaverLogin.logIn();
      if (!await FlutterNaverLogin.isLoggedIn()) return;
      final token = await FlutterNaverLogin.getCurrentAccessToken();
      final callRes = await FirebaseFunctions.instance
          .httpsCallable('naverLogin')
          .call<Map<String, dynamic>>({'accessToken': token.accessToken});
      final firebaseToken = callRes.data['token'] as String;
      await FirebaseAuth.instance.signInWithCustomToken(firebaseToken);
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네이버 로그인에 실패했어요. 다시 시도해주세요.')),
      );
    }
  }

  // 구글 로그인: Firebase 기본 지원. 구글 자격증명으로 바로 signInWithCredential.
  Future<void> _googleLogin(BuildContext context) async {
    try {
      final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();
      if (gUser == null) return; // 사용자가 취소
      final GoogleSignInAuthentication gAuth = await gUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google 로그인에 실패했어요. 다시 시도해주세요.')),
      );
    }
  }

  // 애플 로그인: Firebase 기본 지원. iOS는 네이티브, Android/웹은 Services ID
  // 기반 웹 플로우로 동작해요(clientId는 본인 Services ID로 확인).
  Future<void> _appleLogin(BuildContext context) async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'com.duckauction.signin',
          redirectUri: Uri.parse('https://duck-auction.firebaseapp.com/__/auth/handler'),
        ),
      );
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apple 로그인에 실패했어요. 다시 시도해주세요.')),
      );
    }
  }

  // 게스트 진입 전, 게스트로는 불가능한 동작을 안내하고 동의를 받은 뒤 진입.
  Future<void> _enterGuest(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('게스트로 둘러보기'),
        content: const Text(
          '로그인 없이 경매를 구경할 수 있어요. 다만 입찰·경매 등록·찜·채팅 같은 거래 기능은 로그인 후에 이용할 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16305C)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('둘러볼게요'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
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
                Color(0xFFF4F7FC),
              ],
            ),
          ),
          child: SingleChildScrollView(
            child: ResponsiveContentBounds(
              maxWidth: context.responsive(phone: double.infinity, tablet: 420.0),
              padding: EdgeInsets.zero,
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
                    onTap: () => _kakaoLogin(context),
                  ),
                  const SizedBox(height: 10),
                  _SocialLoginButton(
                    text: '네이버로 계속하기',
                    iconText: 'N',
                    backgroundColor: const Color(0xFF03C75A),
                    foregroundColor: Colors.white,
                    onTap: () => _naverLogin(context),
                  ),
                  const SizedBox(height: 10),
                  _SocialLoginButton(
                    text: 'Google로 계속하기',
                    iconText: 'G',
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF111827),
                    borderColor: const Color(0xFFE2E8F0),
                    onTap: () => _googleLogin(context),
                  ),
                  const SizedBox(height: 10),
                  _SocialLoginButton(
                    text: 'Apple로 계속하기',
                    iconText: '',
                    icon: Icons.apple,
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    onTap: () => _appleLogin(context),
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
                    onPressed: () => _enterGuest(context),
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
  final IconData? icon;
  final VoidCallback onTap;

  const _SocialLoginButton({
    required this.text,
    required this.iconText,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.borderColor,
    this.icon,
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
                child: icon != null
                    ? Icon(icon, size: 19, color: foregroundColor)
                    : Text(
                        iconText,
                        style: TextStyle(
                          fontSize: 15,
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
                backgroundColor: const Color(0xFF16305C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onTap,
              child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16305C),
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
