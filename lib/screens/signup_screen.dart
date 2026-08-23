import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../legal/legal_texts.dart';
import '../services/auth_service.dart';
import 'email_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController passwordConfirmController = TextEditingController();

  bool agreeAge = false;
  bool agreeTerms = false;
  bool agreePrivacy = false;
  bool agreeSafeTrade = false;
  bool agreeMarketing = false;
  bool isLoading = false;

  bool get allRequiredAgreed => agreeAge && agreeTerms && agreePrivacy && agreeSafeTrade;
  bool get allAgreed => allRequiredAgreed && agreeMarketing;

  void _setAllAgreements(bool value) {
    setState(() {
      agreeAge = value;
      agreeTerms = value;
      agreePrivacy = value;
      agreeSafeTrade = value;
      agreeMarketing = value;
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    nicknameController.dispose();
    passwordController.dispose();
    passwordConfirmController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  Future<void> _signup() async {
    final email = emailController.text.trim();
    final nickname = nicknameController.text.trim();
    final password = passwordController.text.trim();
    final passwordConfirm = passwordConfirmController.text.trim();

    if (email.isEmpty || nickname.isEmpty || password.isEmpty || passwordConfirm.isEmpty) {
      _showMessage('모든 항목을 입력해주세요.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('이메일 형식이 올바르지 않습니다.');
      return;
    }

    if (nickname.length < 2) {
      _showMessage('닉네임은 2자 이상 입력해주세요.');
      return;
    }

    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
    if (password.length < 8 || !hasLetter || !hasDigit || !hasSpecial) {
      _showMessage('비밀번호는 영문·숫자·특수문자를 모두 포함해 8자 이상이어야 해요.');
      return;
    }

    if (password != passwordConfirm) {
      _showMessage('비밀번호가 서로 다릅니다.');
      return;
    }

    if (!allRequiredAgreed) {
      _showMessage('필수 약관에 모두 동의해주세요.');
      return;
    }

    setState(() => isLoading = true);

    try {
      await AuthService.signUp(
        email: email,
        password: password,
        nickname: nickname,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('회원가입 완료'),
            content: const Text('가입이 완료됐어요. 이어서 이메일 인증을 진행해주세요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: email)),
        (route) => false,
      );
    } on RejoinBlockedException catch (e) {
      _showMessage('탈퇴한 이메일이에요. ${e.remainingDays}일 후에 다시 가입할 수 있어요.');
    } on FirebaseAuthException catch (e) {
      _showMessage(_authErrorMessage(e.code));
    } catch (_) {
      _showMessage('회원가입 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return '이미 가입된 이메일입니다.';
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다.';
      case 'weak-password':
        return '비밀번호가 너무 약합니다. 8자 이상 입력해주세요.';
      case 'operation-not-allowed':
        return 'Firebase에서 이메일/비밀번호 로그인을 활성화해주세요.';
      default:
        return '회원가입에 실패했습니다. 다시 시도해주세요.';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showAgreementDetail(_AgreementContent agreement) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.74,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      agreement.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      agreement.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Text(
                            agreement.body,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF334155),
                              height: 1.7,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF334155),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('확인', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        titleSpacing: 0,
        title: const Text(
          '이메일 회원가입',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoading ? null : _signup,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF334155),
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                isLoading ? '가입 중...' : '동의하고 회원가입',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SignupHero(),
              const SizedBox(height: 18),
              _FormCard(
                children: [
                  const _FormSectionTitle(
                    title: '기본 정보',
                    subtitle: '로그인에 사용할 정보를 입력해주세요.',
                  ),
                  const SizedBox(height: 18),
                  _AuthTextField(
                    controller: emailController,
                    label: '이메일',
                    hintText: 'example@duckauction.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _AuthTextField(
                    controller: nicknameController,
                    label: '닉네임',
                    hintText: '덕질 닉네임을 입력해주세요',
                  ),
                  const SizedBox(height: 14),
                  _AuthTextField(
                    controller: passwordController,
                    label: '비밀번호',
                    hintText: '영문·숫자·특수문자 포함 8자 이상',
                    obscureText: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  _PasswordStrengthMeter(password: passwordController.text),
                  const SizedBox(height: 14),
                  _AuthTextField(
                    controller: passwordConfirmController,
                    label: '비밀번호 확인',
                    hintText: '비밀번호를 한 번 더 입력해주세요',
                    obscureText: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _AgreementCard(
                allAgreed: allAgreed,
                requiredAgreed: allRequiredAgreed,
                onAllChanged: _setAllAgreements,
                children: [
                  _AgreementTile(
                    value: agreeAge,
                    title: '만 14세 이상입니다.',
                    requiredText: '필수',
                    onChanged: (value) => setState(() => agreeAge = value),
                  ),
                  _AgreementTile(
                    value: agreeTerms,
                    title: '서비스 이용약관에 동의합니다.',
                    requiredText: '필수',
                    onChanged: (value) => setState(() => agreeTerms = value),
                    onDetail: () => _showAgreementDetail(_AgreementContent.terms),
                  ),
                  _AgreementTile(
                    value: agreePrivacy,
                    title: '개인정보 수집 및 이용에 동의합니다.',
                    requiredText: '필수',
                    onChanged: (value) => setState(() => agreePrivacy = value),
                    onDetail: () => _showAgreementDetail(_AgreementContent.privacy),
                  ),
                  _AgreementTile(
                    value: agreeSafeTrade,
                    title: '안전거래 정책에 동의합니다.',
                    requiredText: '필수',
                    onChanged: (value) => setState(() => agreeSafeTrade = value),
                    onDetail: () => _showAgreementDetail(_AgreementContent.safeTrade),
                  ),
                  _AgreementTile(
                    value: agreeMarketing,
                    title: '마케팅 정보 수신에 동의합니다.',
                    requiredText: '선택',
                    optional: true,
                    onChanged: (value) => setState(() => agreeMarketing = value),
                    onDetail: () => _showAgreementDetail(_AgreementContent.marketing),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignupHero extends StatelessWidget {
  const _SignupHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '덕옥션 시작하기',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 25,
              height: 1.15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 9),
          Text(
            '굿즈 경매를 안전하게 이용하기 위해\n기본 정보와 필수 약관 동의가 필요해요.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final List<Widget> children;

  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _FormSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _FormSectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AgreementCard extends StatelessWidget {
  final bool allAgreed;
  final bool requiredAgreed;
  final ValueChanged<bool> onAllChanged;
  final List<Widget> children;

  const _AgreementCard({
    required this.allAgreed,
    required this.requiredAgreed,
    required this.onAllChanged,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: requiredAgreed ? const Color(0xFFE2E8F0) : const Color(0xFFFFC9D6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onAllChanged(!allAgreed),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  _CheckBoxIcon(checked: allAgreed),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '전체 동의',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '필수 및 선택 항목을 한 번에 동의합니다.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _AgreementTile extends StatelessWidget {
  final bool value;
  final String title;
  final String requiredText;
  final bool optional;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onDetail;

  const _AgreementTile({
    required this.value,
    required this.title,
    required this.requiredText,
    required this.onChanged,
    this.optional = false,
    this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = optional ? const Color(0xFF64748B) : const Color(0xFFFF3D68);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            _CheckBoxIcon(checked: value),
            const SizedBox(width: 10),
            _AgreementChip(text: requiredText, color: chipColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onDetail != null)
              TextButton(
                onPressed: onDetail,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 34),
                  foregroundColor: const Color(0xFF64748B),
                ),
                child: const Text('보기', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckBoxIcon extends StatelessWidget {
  final bool checked;

  const _CheckBoxIcon({required this.checked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? const Color(0xFF334155) : Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: checked ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
          : null,
    );
  }
}

class _AgreementChip extends StatelessWidget {
  final String text;
  final Color color;

  const _AgreementChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
  });

  @override
  State<_AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<_AuthTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: _obscured,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            // 비밀번호 입력란 우측: 눈 모양 버튼(입력값 표시/숨김 토글)
            suffixIcon: widget.obscureText
                ? IconButton(
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF94A3B8),
                      size: 21,
                    ),
                    tooltip: _obscured ? '비밀번호 표시' : '비밀번호 숨기기',
                  )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF334155), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// 비밀번호 강도(영문·숫자·특수문자·길이) 표시 막대. 비어 있으면 아무것도 안 그림.
class _PasswordStrengthMeter extends StatelessWidget {
  final String password;
  const _PasswordStrengthMeter({required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
    final longEnough = password.length >= 8;
    final score = [hasLetter, hasDigit, hasSpecial, longEnough].where((e) => e).length;
    const labels = ['매우 약함', '약함', '보통', '안전', '매우 안전'];
    final color = score >= 3
        ? const Color(0xFF16A34A)
        : (score == 2 ? const Color(0xFFF59E0B) : const Color(0xFFDC2626));
    final missing = <String>[];
    if (!hasLetter) missing.add('영문');
    if (!hasDigit) missing.add('숫자');
    if (!hasSpecial) missing.add('특수문자');
    if (!longEnough) missing.add('8자 이상');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i < 3 ? 5 : 0),
                  decoration: BoxDecoration(
                    color: i < score ? color : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            missing.isEmpty
                ? '안전한 비밀번호예요 · ${labels[score]}'
                : '${missing.join('·')} 를 포함해주세요',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: missing.isEmpty ? const Color(0xFF16A34A) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgreementContent {
  final String title;
  final String subtitle;
  final String body;

  const _AgreementContent({
    required this.title,
    required this.subtitle,
    required this.body,
  });

  static const terms = _AgreementContent(
    title: '서비스 이용약관',
    subtitle: '덕옥션 서비스 이용을 위한 기본 약관입니다.',
    body: kTermsOfServiceText,
  );

  static const privacy = _AgreementContent(
    title: '개인정보 수집 및 이용 동의',
    subtitle: '회원가입 및 안전한 거래 제공을 위한 개인정보 처리 안내입니다.',
    body: """수집 항목
이메일, 닉네임, 비밀번호, 휴대폰 인증 정보, 서비스 이용 기록, 거래 기록, 문의 및 신고 내역을 수집할 수 있습니다.

수집 목적
회원 식별, 로그인, 거래 안전성 확보, 고객 문의 대응, 부정 이용 방지, 서비스 품질 개선을 위해 사용됩니다.

보유 기간
회원 탈퇴 시까지 보관하며, 관계 법령에 따라 보존이 필요한 정보는 정해진 기간 동안 보관될 수 있습니다.

동의 거부 권리
개인정보 수집 및 이용에 동의하지 않을 수 있으나, 이 경우 덕옥션 회원가입 및 서비스 이용이 제한될 수 있습니다.""",
  );

  static const safeTrade = _AgreementContent(
    title: '안전거래 정책',
    subtitle: '경매 거래의 신뢰를 지키기 위한 필수 정책입니다.',
    body: """입찰 책임
회원은 본인이 입력한 입찰 금액과 경매 조건을 확인한 뒤 입찰해야 합니다. 입찰 후 단순 변심에 따른 취소는 제한될 수 있습니다.

결제 기한
경매 마감 후 결제 순위가 정해지며, 1순위 낙찰자는 낙찰 후 24시간 이내, 2·3순위 낙찰자는 각 순위 승계 시점부터 각각 12시간 이내에 결제해야 합니다. 기한 내 미결제 시 다음 순위로 자동 승계되며, 순위자 전원이 결제하지 않으면 해당 경매는 유찰됩니다.

판매자 책임
판매자는 실제 보유한 상품만 등록해야 하며, 위조품, 도난품, 판매가 금지된 상품을 등록해서는 안 됩니다. 결제 완료 후 3일 이내에 배송 준비를 시작해야 하며, 3일이 지나도록 배송 준비가 확인되지 않으면 구매자 보호를 위해 결제가 자동으로 취소·환불될 수 있습니다.

구매자 책임
구매자는 낙찰 후 결제 및 거래 절차를 성실히 이행해야 합니다. 상품을 받으면 [받았어요]를 눌러 구매확정을 해주세요. 판매자가 발송(수령 표시)한 뒤 3일 이내에 구매확정이 없으면 자동으로 구매확정(거래완료) 처리됩니다. 발송 후 7일이 지나도 수령 확인이 없으면 확인 알림이 발송되고, 받지 못한 경우 이후 7일 간격으로 재확인됩니다. 반복적인 미결제 또는 거래 방해 행위가 확인될 경우 이용이 제한될 수 있습니다.

결제 취소 및 환불
배송 준비 전에 거래가 성립되지 않거나 위 기한이 초과된 경우 결제 금액은 정해진 절차에 따라 자동으로 취소·환불됩니다. 배송 지연이나 상품 문제가 있는 경우 확인 알림의 [받지 못했어요]를 통해 재확인 및 결제취소(환불) 절차를 안내받을 수 있습니다. 다만 구매확정(거래완료) 이후에는 단순 변심에 따른 환불이 제한될 수 있습니다.

서비스의 지위 및 책임
덕옥션은 회원 간(C2C) 거래를 중개하는 통신판매중개자로, 거래의 직접 당사자가 아닙니다. 상품의 진위·품질·배송·환불 등 거래 자체에 관한 책임은 원칙적으로 판매자와 구매자 당사자에게 있으며, 덕옥션은 관련 법령이 허용하는 범위에서 책임이 제한될 수 있습니다. 자세한 내용은 서비스 이용약관을 따릅니다.

분쟁 및 신고
거래 중 문제가 발생한 경우 덕옥션은 신고 내역, 채팅 기록, 거래 기록 등을 바탕으로 사실관계를 확인하고 필요한 조치를 취할 수 있습니다.

정책 위반
허위 등록, 사기성 거래, 위조품 판매, 부적절한 채팅, 거래 방해가 확인될 경우 계정 이용 제한 및 상품 노출 제한이 적용될 수 있습니다.""",
  );

  static const marketing = _AgreementContent(
    title: '마케팅 정보 수신 동의',
    subtitle: '이벤트, 혜택, 신규 기능 안내를 위한 선택 동의입니다.',
    body: """수신 내용
덕옥션의 이벤트, 광고, 프로모션, 신규 기능, 추천 상품, 판매자 혜택 정보를 이메일 또는 앱 알림으로 안내할 수 있습니다.

동의 철회
마케팅 수신 동의는 선택 사항이며, 가입 후에도 마이페이지 또는 설정 화면에서 언제든지 철회할 수 있습니다.

서비스 안내와의 구분
거래, 결제, 보안, 약관 변경 등 서비스 이용에 필요한 필수 안내는 마케팅 수신 동의 여부와 관계없이 발송될 수 있습니다.""",
  );
}
