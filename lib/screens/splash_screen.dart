import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/deep_link.dart';
import '../utils/app_update_gate.dart';
import 'email_verification_screen.dart';
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
    // 웹 결제·본인인증을 마치고 돌아온 경우(앱이 통째로 새로고침됨)엔 스플래시를
    // 3초 보여주지 않고 곧바로 진행해서 결과를 빠르게 안내합니다.
    final returningFromWeb = DeepLink.hasPendingPayment || DeepLink.hasPendingIdentity;
    await Future.delayed(
      Duration(seconds: returningFromWeb ? 0 : 3),
    );

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

    if (user != null) {
      try {
        await user.reload();
      } catch (_) {
        // 네트워크 문제로 새로고침이 실패해도 캐시된 값으로 계속 진행합니다.
      }
      user = FirebaseAuth.instance.currentUser;
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) {
          if (user != null && user!.emailVerified) {
            return const HomeScreen();
          }

          if (user != null && !user!.emailVerified) {
            return EmailVerificationScreen(email: user!.email ?? '');
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

    // 공유 링크(예: /products/abc123)로 들어온 경우, 홈/로그인 화면이 자리잡은
    // 뒤에 그 위로 해당 상품/프로필 화면을 한 번 더 열어줍니다. 평소처럼
    // duckauction.com으로 그냥 들어온 경우에는 여기서 할 일이 없습니다.
    unawaited(_openPendingDeepLink());
    // 웹에서 결제를 마치고 돌아온 경우, 결제를 검증하고 결과를 안내합니다.
    unawaited(_handlePendingPayment());
    // 웹에서 본인인증을 마치고 돌아온 경우, 인증을 검증하고 결과를 안내합니다.
    unawaited(_handlePendingIdentity());
    // Play 인앱 업데이트: 트랙에 새 빌드가 있으면 업데이트 안내 팝업을 띄워요.
    unawaited(_maybePromptUpdate());
  }

  /// 앱이 켜져 홈이 자리잡은 뒤, Play 인앱 업데이트로 새 버전 여부를 확인하고
  /// 새 버전이 있으면 업데이트 안내 팝업을 띄웁니다.
  /// (웹/사이드로드/디버그 설치에선 Play가 버전 정보를 몰라 조용히 넘어가요.)
  Future<void> _maybePromptUpdate() async {
    await Future.delayed(const Duration(milliseconds: 800));
    final status = await AppUpdateGate.check();
    if (status != UpdateStatus.available) return;
    final ctx = DeepLink.navigatorKey.currentContext;
    if (ctx == null) return;
    await AppUpdateGate.promptUpdate(ctx);
  }

  /// 웹 본인인증(verify.html) 후 돌아온 결과를 처리합니다. 성공이면 서버에
  /// confirmIdentityVerification으로 검증(사용자 문서에 인증 저장)하고 결과 팝업을 띄웁니다.
  Future<void> _handlePendingIdentity() async {
    final idv = DeepLink.consumePendingIdentity();
    if (idv == null) return;

    // 홈 화면 전환 애니메이션(약 600ms)이 끝난 뒤에 안내창을 띄웁니다.
    await Future.delayed(const Duration(milliseconds: 850));

    if (idv.isFailure) {
      final detail = <String>[
        if (idv.errorMessage != null && idv.errorMessage!.trim().isNotEmpty) idv.errorMessage!.trim(),
        if (idv.errorCode != null && idv.errorCode!.trim().isNotEmpty) '(코드: ${idv.errorCode!.trim()})',
      ].join('\n');
      _showPaymentResultDialog(
        false,
        detail.isEmpty ? '본인인증이 취소되었어요.' : detail,
        title: '본인인증이 완료되지 않았어요',
      );
      return;
    }
    try {
      await FirebaseFunctions.instance
          .httpsCallable('confirmIdentityVerification')
          .call<Map<String, dynamic>>(<String, dynamic>{
        'identityVerificationId': idv.identityVerificationId,
      });
      _showPaymentResultDialog(
        true,
        '본인인증이 완료됐어요.\n이제 판매(경매)를 등록할 수 있어요.',
        title: '본인인증이 완료됐어요',
      );
    } catch (e) {
      _showPaymentResultDialog(
        false,
        '본인인증 확인에 실패했어요. 잠시 후 다시 시도해주세요.',
        title: '본인인증이 완료되지 않았어요',
      );
    }
  }

  /// 웹 결제(pay.html) 후 돌아온 결과를 처리합니다. 성공이면 서버에
  /// confirmTossPayment(토스)/confirmPortonePayment(구 포트원)로 결제를 검증
  /// (상품 'paid' 갱신)하고, 결과 팝업을 띄웁니다.
  Future<void> _handlePendingPayment() async {
    final pmt = DeepLink.consumePendingPayment();
    if (pmt == null) return;

    // 홈 화면 전환 애니메이션(약 600ms)이 끝난 뒤에 안내창을 띄워야, 전환 도중
    // 띄웠다가 살짝 떴다 사라지는 현상을 막을 수 있습니다.
    await Future.delayed(const Duration(milliseconds: 850));

    if (pmt.isFailure) {
      // 토스/포트원이 돌려준 실제 사유(코드·메시지)를 그대로 보여줘서
      // 도메인 미등록·테스트카드 등 원인을 바로 알 수 있게 합니다.
      final detail = <String>[
        if (pmt.errorMessage != null && pmt.errorMessage!.trim().isNotEmpty)
          pmt.errorMessage!.trim(),
        if (pmt.errorCode != null && pmt.errorCode!.trim().isNotEmpty)
          '(코드: ${pmt.errorCode!.trim()})',
      ].join('\n');
      _showPaymentResultDialog(
        false,
        detail.isEmpty ? '결제가 취소되었어요.' : '결제가 완료되지 않았어요.\n$detail',
      );
      return;
    }
    try {
      if (pmt.isToss) {
        // 토스 결제 승인: paymentKey/orderId/amount로 서버가 최종 승인·검증.
        await FirebaseFunctions.instance
            .httpsCallable('confirmTossPayment')
            .call<Map<String, dynamic>>(<String, dynamic>{
          'paymentKey': pmt.paymentKey,
          'orderId': pmt.orderId,
          'amount': pmt.amount,
          'productId': pmt.productId,
        });
      } else {
        // 구 포트원(이니시스) 경로 — 보존.
        await FirebaseFunctions.instance
            .httpsCallable('confirmPortonePayment')
            .call<Map<String, dynamic>>(<String, dynamic>{
          'paymentId': pmt.paymentId,
          'productId': pmt.productId,
        });
      }
      await DuckAuctionStore.refreshProductsNow();
      _showPaymentResultDialog(true, '결제가 정상적으로 처리됐어요.\n판매자와 배송 정보를 확인해주세요.');
    } catch (e) {
      _showPaymentResultDialog(
          false, '결제 확인에 실패했어요. 결제가 정상 처리됐는지 판매자에게 확인해주세요.');
    }
  }

  void _showPaymentResultDialog(bool ok, String message, {String? title}) {
    final ctx = DeepLink.navigatorKey.currentContext;
    if (ctx == null) return;
    final resolvedTitle = title ?? (ok ? '결제가 완료됐어요' : '결제가 완료되지 않았어요');
    showDialog<void>(
      context: ctx,
      // 사용자가 '확인'을 누를 때까지 유지되게 해서, 반짝 떴다 사라지지 않게 합니다.
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          resolvedTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPendingDeepLink() async {
    final target = DeepLink.consumePending();
    if (target == null) return;

    try {
      if (target.type == DeepLinkType.product) {
        final snapshot = await FirebaseFirestore.instance
            .collection('products')
            .where(FieldPath.documentId, isEqualTo: target.id)
            .limit(1)
            .get();
        if (snapshot.docs.isEmpty) return;
        final product = ProductItem.fromFirestore(snapshot.docs.first);
        DeepLink.navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
        );
      } else {
        // 프로필 화면은 ProductItem의 sellerId를 기준으로 users/{uid}를 실시간
        // 구독해서 실제 프로필을 그려주므로, 나머지 필드는 최소한의 placeholder면 됩니다.
        final placeholder = ProductItem(
          title: '',
          category: '기타',
          price: '0원',
          bids: '0명',
          time: '',
          imageEmoji: '🐥',
          likes: '0',
          sellerId: target.id,
          sellerName: '덕친',
          sellerSalesCount: 0,
        );
        DeepLink.navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => SellerProfileScreen(seller: placeholder)),
        );
      }
    } catch (e) {
      // 딥링크 열기가 실패해도 이미 홈/로그인 화면은 정상적으로 떠 있으므로
      // 조용히 무시합니다(잘못된 링크, 삭제된 상품 등).
      // ignore: avoid_print
      print('Deep link open failed: $e');
    }
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

                // 화면이 작아도 로딩 스피너까지 다 보이도록, 전체 콘텐츠를 화면
                // 높이에 맞춰 필요한 만큼만 축소해요(FittedBox scaleDown). 잘려서
                // 안 보이던 하단(스피너·안내문구)이 항상 보이게 됩니다.
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: (constraints.maxWidth - 48).clamp(240.0, 420.0),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
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
