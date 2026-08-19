part of '../home_screen.dart';

/// 토스페이먼츠 '결제위젯'을 인앱 웹뷰로 띄우는 결제 화면이에요.
/// (구 포트원/이니시스 연동을 토스로 전환 — 호출부 호환을 위해 클래스명은 유지)
///
/// 흐름: 이 화면이 열리면 웹뷰 안에서 토스 결제위젯 SDK가 결제수단 UI를 렌더링하고,
/// 사용자가 [결제하기]를 누르면 토스 결제창으로 이동해요. 결제를 마치면 토스가
/// successUrl로 돌아오는데, 그 URL을 웹뷰에서 가로채 paymentKey/orderId/amount를
/// 뽑아 서버(Firebase Function `confirmTossPayment`)로 결제 승인을 요청해요.
/// 서버가 토스 승인 API(/v1/payments/confirm)로 최종 승인·검증한 뒤 결과를 담아
/// 이 화면을 닫습니다.
///
/// 지금은 토스 '테스트 키'로 동작해요(실결제 X). 전자결제 계약/심사가 끝나면
/// 아래 _kTossClientKey를 실제 클라이언트 키로, 서버(functions/index.js)의
/// TOSS_SECRET_KEY(현재 테스트 시크릿)를 실제 시크릿 키로 바꾸면 됩니다.

// 웹 결제(pay.html) 경로에서 쓰는 앱 도메인. (home_screen.startWebCheckout에서 참조)
const String _kPortOneBaseUrl = 'https://duck-auction.web.app';

// 포트원 Store ID — 본인인증(통합인증) 화면 등에서 공용으로 사용해요(테스트/운영 공통).
const String _kPortOneStoreId = 'store-d2a85cca-0b2d-4562-9f2f-bcfb98ffc83b';
// ── 구 포트원 '결제' 채널 상수(보존 — 롤백용, 현재 결제는 토스로 전환됨) ──
//   const String _kPortOneChannelKey = 'channel-key-adcad1b6-e25d-4b77-bc8a-3ebcabfb170c';
//   const String _kPortOneRedirectUrl = 'https://duck-auction.web.app/payment/complete';

// 토스페이먼츠 '결제위젯' 테스트 클라이언트 키. (서버 TOSS_SECRET_KEY와 짝이 맞는 위젯 테스트 키)
// ⚠️ 정식 오픈 시 토스 개발자센터에서 발급한 '실연동' 위젯 클라이언트 키로 교체.
const String _kTossClientKey = 'test_gck_docs_Ovk5rk1EwkEbP0W43n07xlzm';
// 결제 완료/실패 시 웹뷰가 이동하는 주소(가로채서 결과 처리). 실제 페이지는 없어도 됩니다.
const String _kTossSuccessUrl = 'https://duck-auction.web.app/payment/toss-success';
const String _kTossFailUrl = 'https://duck-auction.web.app/payment/toss-fail';

/// 결제 화면이 돌려주는 결과값이에요.
class TossPaymentResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;

  const TossPaymentResult({required this.success, this.message, this.data});
}

class TossCheckoutScreen extends StatefulWidget {
  /// 토스 결제 주문번호(orderId)로 쓰는 값. 가맹점에서 유니크하게 관리.
  final String orderId;

  /// 주문명(예: '치이카와 인형 세트').
  final String orderName;

  /// 결제 금액(원). 낙찰가 + 배송비.
  final int amount;

  /// 구매자 이름(닉네임).
  final String customerName;

  /// 구매자 식별 키(로그인 uid).
  final String? customerKey;

  /// 결제 대상 상품 id. 서버 검증 후 상품 상태를 갱신할 때 사용해요.
  final String? productId;

  const TossCheckoutScreen({
    super.key,
    required this.orderId,
    required this.orderName,
    required this.amount,
    required this.customerName,
    this.customerKey,
    this.productId,
  });

  @override
  State<TossCheckoutScreen> createState() => _TossCheckoutScreenState();
}

class _TossCheckoutScreenState extends State<TossCheckoutScreen> {
  bool _webviewLoading = true;
  bool _confirming = false;
  bool _finished = false;
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;

            // 토스 결제 완료/실패 후 돌아오는 주소(successUrl/failUrl)를 가로채요.
            if (url.startsWith(_kTossSuccessUrl) || url.startsWith(_kTossFailUrl)) {
              _handleRedirect(Uri.parse(url));
              return NavigationDecision.prevent;
            }

            // 카드사·간편결제 앱으로 넘어가는 딥링크(intent://, 각종 앱 스킴)는
            // 외부 앱으로 열어줘요.
            final scheme = Uri.parse(url).scheme.toLowerCase();
            if (scheme != 'http' &&
                scheme != 'https' &&
                scheme != 'about' &&
                scheme != 'data' &&
                scheme != 'blob') {
              _launchExternal(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _webviewLoading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _webviewLoading = false);
          },
        ),
      )
      ..loadHtmlString(_buildHtml(), baseUrl: _kPortOneBaseUrl);
  }

  Future<void> _launchExternal(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  static String _escapeJs(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '')
        .replaceAll('<', '\\u003c')
        .replaceAll('>', '\\u003e');
  }

  /// 토스 customerKey 규칙(영문/숫자/-_=.@, 2~50자)에 맞춰 안전한 키를 만들어요.
  static String _tossCustomerKey(String raw, String orderId) {
    final cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9\-_=.@]'), '');
    final fallback = 'guest_${orderId.replaceAll(RegExp(r'[^a-zA-Z0-9\-_=.@]'), '')}';
    var key = cleaned.length >= 2 ? cleaned : fallback;
    if (key.length < 2) key = 'guest_00';
    return key.length > 50 ? key.substring(0, 50) : key;
  }

  String _buildHtml() {
    final orderId = _escapeJs(widget.orderId);
    final orderName = _escapeJs(widget.orderName);
    final customerName = _escapeJs(widget.customerName);
    final rawKey = (widget.customerKey == null || widget.customerKey!.trim().isEmpty)
        ? ''
        : widget.customerKey!.trim();
    final customerKey = _escapeJs(_tossCustomerKey(rawKey, widget.orderId));

    return '''
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
  <title>덕옥션 결제</title>
  <script src="https://js.tosspayments.com/v1/payment-widget"></script>
  <style>
    body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, 'Apple SD Gothic Neo', 'Malgun Gothic', sans-serif; background: #ffffff; color: #16305C; }
    #wrap { padding: 8px 10px 24px; display: none; }
    #payButton { width: 100%; height: 54px; border: 0; border-radius: 14px; background: #16305C; color: #fff; font-size: 16px; font-weight: 800; margin-top: 12px; }
    #payButton:disabled { background: #94A3B8; }
    #msg { padding: 40px 20px; text-align: center; font-weight: 700; }
  </style>
</head>
<body>
  <div id="msg">결제창을 준비하고 있어요…</div>
  <div id="wrap">
    <div id="payment-method"></div>
    <div id="agreement"></div>
    <button id="payButton">결제하기</button>
  </div>
  <script>
    (function () {
      var clientKey = "$_kTossClientKey";
      var customerKey = "$customerKey";
      var amount = ${widget.amount};
      function fail(msg) {
        window.location.href = "$_kTossFailUrl?code=ERROR&message=" + encodeURIComponent(msg || "결제창을 불러오지 못했어요.");
      }
      try {
        var paymentWidget = PaymentWidget(clientKey, customerKey);
        paymentWidget.renderPaymentMethods("#payment-method", { value: amount }, { variantKey: "DEFAULT" });
        paymentWidget.renderAgreement("#agreement", { variantKey: "AGREEMENT" });
        document.getElementById("msg").style.display = "none";
        document.getElementById("wrap").style.display = "block";
        var btn = document.getElementById("payButton");
        btn.textContent = amount.toLocaleString("ko-KR") + "원 결제하기";
        btn.addEventListener("click", function () {
          btn.disabled = true;
          paymentWidget.requestPayment({
            orderId: "$orderId",
            orderName: "$orderName",
            customerName: "$customerName",
            successUrl: "$_kTossSuccessUrl",
            failUrl: "$_kTossFailUrl"
          }).catch(function (e) {
            // 사용자가 결제창을 닫거나 오류가 나면 다시 시도할 수 있게 버튼 복구.
            btn.disabled = false;
          });
        });
      } catch (e) {
        fail((e && e.message) ? e.message : "결제창을 불러오지 못했어요.");
      }
    })();
  </script>
</body>
</html>
''';
  }

  Future<void> _handleRedirect(Uri uri) async {
    if (_confirming || _finished) return;
    final params = uri.queryParameters;
    final code = params['code'];
    final isFail = uri.toString().startsWith(_kTossFailUrl) ||
        (code != null && code.trim().isNotEmpty);
    if (isFail) {
      final message = params['message'];
      _finish(TossPaymentResult(
        success: false,
        message: (message == null || message.trim().isEmpty)
            ? '결제가 취소되었어요.'
            : message,
      ));
      return;
    }

    final paymentKey = (params['paymentKey'] ?? '').trim();
    final orderId = params['orderId'] ?? widget.orderId;
    final amount = int.tryParse(params['amount'] ?? '') ?? widget.amount;
    if (paymentKey.isEmpty) {
      _finish(const TossPaymentResult(
        success: false,
        message: '결제 정보를 확인하지 못했어요.',
      ));
      return;
    }

    setState(() => _confirming = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('confirmTossPayment')
          .call<Map<String, dynamic>>(<String, dynamic>{
        'paymentKey': paymentKey,
        'orderId': orderId,
        'amount': amount,
        'productId': widget.productId,
        if (widget.customerKey != null && widget.customerKey!.trim().isNotEmpty)
          'buyerId': widget.customerKey!.trim(),
      });
      _finish(TossPaymentResult(
        success: true,
        data: Map<String, dynamic>.from(result.data),
      ));
    } on FirebaseFunctionsException catch (e) {
      _finish(TossPaymentResult(
        success: false,
        message: e.message ?? '결제 검증에 실패했어요.',
      ));
    } catch (_) {
      _finish(const TossPaymentResult(
        success: false,
        message: '결제 확인 중 오류가 발생했어요. 잠시 후 다시 시도해주세요.',
      ));
    }
  }

  void _finish(TossPaymentResult result) {
    if (_finished) return;
    _finished = true;
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        foregroundColor: const Color(0xFF16305C),
        title: const Text('결제', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_webviewLoading || _confirming)
            Container(
              color: Colors.white.withValues(alpha: _confirming ? 0.86 : 1.0),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF16305C)),
                  const SizedBox(height: 16),
                  Text(
                    _confirming ? '결제를 확인하고 있어요…' : '결제창을 불러오는 중…',
                    style: const TextStyle(
                      color: Color(0xFF16305C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
