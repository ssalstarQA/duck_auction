import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool keepLogin = false;
  bool saveEmail = false;

  @override
  void initState() {
    super.initState();
    _loadKeepLogin();
  }

  Future<void> _loadKeepLogin() async {
    final savedKeepLogin = await AuthService.isKeepLoginEnabled();
    final savedEmailEnabled = await AuthService.isSaveEmailEnabled();
    final savedEmail = await AuthService.getSavedEmail();

    if (!mounted) return;
    setState(() {
      keepLogin = savedKeepLogin;
      saveEmail = savedEmailEnabled;
      if (savedEmailEnabled && savedEmail.isNotEmpty) {
        emailController.text = savedEmail;
      }
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('이메일과 비밀번호를 모두 입력해주세요.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('이메일 형식이 올바르지 않습니다.');
      return;
    }

    setState(() => isLoading = true);

    try {
      await AuthService.signIn(
        email: email,
        password: password,
        keepLogin: keepLogin,
      );

      await AuthService.setSavedEmail(
        enabled: saveEmail,
        email: email,
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(_authErrorMessage(e.code));
    } catch (_) {
      _showMessage('로그인 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다.';
      case 'user-disabled':
        return '이용이 제한된 계정입니다.';
      case 'user-not-found':
        return '가입되지 않은 이메일입니다.';
      case 'wrong-password':
        return '비밀번호가 올바르지 않습니다.';
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      default:
        return '로그인에 실패했습니다. 다시 시도해주세요.';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _goSignup() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: '이메일 로그인',
      subtitle: '가입한 이메일과 비밀번호를 입력해주세요.',
      children: [
        _AuthTextField(
          controller: emailController,
          label: '이메일',
          hintText: 'example@duckauction.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _AuthTextField(
          controller: passwordController,
          label: '비밀번호',
          hintText: '비밀번호를 입력해주세요',
          obscureText: true,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 0,
          children: [
            _AuthCheckItem(
              value: saveEmail,
              label: '아이디 저장',
              isLoading: isLoading,
              onChanged: (value) {
                setState(() => saveEmail = value ?? false);
              },
            ),
            _AuthCheckItem(
              value: keepLogin,
              label: '로그인 상태 유지',
              isLoading: isLoading,
              onChanged: (value) {
                setState(() => keepLogin = value ?? false);
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              _showMessage('아이디/비밀번호 찾기는 다음 단계에서 연결할 예정이에요.');
            },
            child: const Text(
              '아이디/비밀번호 찾기',
              style: TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _PrimaryButton(
          text: isLoading ? '로그인 중...' : '로그인',
          onTap: isLoading ? null : _login,
        ),
        const SizedBox(height: 16),
        _OutlineButton(
          text: '아직 계정이 없나요? 회원가입',
          onTap: _goSignup,
        ),
      ],
    );
  }
}


class _AuthCheckItem extends StatelessWidget {
  final bool value;
  final String label;
  final bool isLoading;
  final ValueChanged<bool?> onChanged;

  const _AuthCheckItem({
    required this.value,
    required this.label,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: isLoading ? null : () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: value,
              activeColor: const Color(0xFF334155),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              onChanged: isLoading ? null : onChanged,
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        foregroundColor: const Color(0xFF334155),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 26),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFF1F5F9),
              ],
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),
                Image.asset(
                  'assets/image/image/main_title.png',
                  width: 210,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 26),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF777777),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                ...children,
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFFFD7E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFF334155),
                width: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF334155),
          disabledBackgroundColor: const Color(0xFFCBD5E1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF334155),
          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
