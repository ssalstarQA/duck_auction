import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _floatController;

  late final Animation<double> _fadeAnimation;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _floatAnimation = Tween<double>(
      begin: -6,
      end: 6,
    ).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeController.forward();
    _moveNext();
  }

  Future<void> _moveNext() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    await _fadeController.reverse();

    if (!mounted) return;

    // 웹에서는 Firebase Auth가 브라우저 저장소에서 세션을 복구하는 데
    // 시간이 걸릴 수 있습니다. null 이벤트 하나만 보고 로그인 화면으로 보내지 않고
    // 여러 번 currentUser를 확인합니다.
    User? user = FirebaseAuth.instance.currentUser;
    for (var i = 0; i < 20 && user == null; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      user = FirebaseAuth.instance.currentUser;
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) {
          if (user != null) {
            return const HomeScreen();
          }

          return const LoginScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            width: double.infinity,
            height: double.infinity,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isShort = constraints.maxHeight < 720;

                return SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 24),
                            AnimatedBuilder(
                              animation: _floatAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, 38 + _floatAnimation.value),
                                  child: child,
                                );
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: -115,
                                    top: 70,
                                    child: Opacity(
                                      opacity: 0.30,
                                      child: Icon(
                                        Icons.cloud,
                                        color: Color(0xFFE2E8F0),
                                        size: 52,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: -115,
                                    top: 110,
                                    child: Opacity(
                                      opacity: 0.30,
                                      child: Icon(
                                        Icons.cloud,
                                        color: Color(0xFFE2E8F0),
                                        size: 58,
                                      ),
                                    ),
                                  ),
                                  const Positioned(
                                    left: -40,
                                    top: 45,
                                    child: Text(
                                      "✦",
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 22,
                                      ),
                                    ),
                                  ),
                                  const Positioned(
                                    right: -36,
                                    top: 70,
                                    child: Text(
                                      "✦",
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                  const Positioned(
                                    left: -35,
                                    bottom: 75,
                                    child: Text(
                                      "✦",
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  Image.asset(
                                    'assets/image/image/main_duck.png',
                                    width: isShort ? 320 : 380,
                                    fit: BoxFit.contain,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isShort ? 20 : 32),
                            Image.asset(
                              'assets/image/image/main_title.png',
                              width: isShort ? 250 : 290,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              "덕질의 가치를 경매하다.",
                              style: TextStyle(
                                fontSize: 22,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: isShort ? 18 : 24),
                            const SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                color: Color(0xffff6f91),
                                backgroundColor: Color(0xffffd8e2),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "덕질을 준비중입니다...",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                color: Color(0xffff6f91),
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: isShort ? 16 : 22),
                            const Text(
                              "v1.0.0",
                              style: TextStyle(
                                color: Color(0xffb6a1a6),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
