part of '../home_screen.dart';

/// 포트원(PortOne) V2 통합인증으로 KG이니시스 본인인증창을 인앱 웹뷰로 띄우는 화면이에요.
/// 판매(경매) 등록 전 '필수 본인인증'에 사용합니다.
///
/// 흐름: 화면이 열리면 웹뷰 안에서 포트원 SDK가 requestIdentityVerification()을
/// 호출해 이니시스 본인인증창으로 이동해요. 인증을 마치면 포트원이 redirectUrl로
/// 돌아오는데, 그 URL을 웹뷰에서 가로채 identityVerificationId를 뽑아 서버
/// (Firebase Function `confirmIdentityVerification`)로 검증을 요청해요. 서버가
/// 포트원 REST API로 실제 인증 상태(VERIFIED)를 확인하고 사용자 문서에 저장한 뒤
/// 이 화면을 닫습니다.
///
/// 지금은 '테스트(통합인증) 채널'로 동작해요. 정식 오픈 시 아래 _kIdvChannelKey만
/// 운영 통합인증 채널키로 바꾸면 됩니다. (Store ID는 결제와 공용이에요.)
// ⚠️ 테스트 통합인증 채널키 — 정식 오픈 시 포트원 콘솔의 '운영(실연동)' 통합인증 채널키로 교체.
const String _kIdvChannelKey = 'channel-key-a1d19937-77ac-47f0-9299-ef5928f3d030';
const String _kIdvRedirectUrl = 'https://duck-auction.web.app/identity/complete';

/// 본인인증 화면이 돌려주는 결과값이에요.
class IdentityVerificationResult {
  final bool success;
  final String? message;
  final String? name;

  const IdentityVerificationResult({required this.success, this.message, this.name});
}

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() => _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen> {
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

            // 포트원 인증 완료 후 redirectUrl로 돌아오는 걸 가로채요.
            if (url.startsWith(_kIdvRedirectUrl)) {
              _handleRedirect(Uri.parse(url));
              return NavigationDecision.prevent;
            }

            // 통신사·인증 앱으로 넘어가는 딥링크(intent://, 각종 앱 스킴)는 외부 앱으로 열어줘요.
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
      ..loadHtmlString(_buildHtml(), baseUrl: 'https://duck-auction.web.app');
  }

  Future<void> _launchExternal(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  String _buildHtml() {
    final idvId = 'duckauction-idv-${DateTime.now().millisecondsSinceEpoch}';
    return '''
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
  <title>덕옥션 본인인증</title>
  <script src="https://cdn.portone.io/v2/browser-sdk.js"></script>
  <style>
    body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, 'Apple SD Gothic Neo', 'Malgun Gothic', sans-serif; background: #ffffff; color: #16305C; }
    #msg { padding: 40px 20px; text-align: center; font-weight: 700; }
  </style>
</head>
<body>
  <div id="msg">본인인증 창을 준비하고 있어요…</div>
  <script>
    (async function () {
      var redirect = "$_kIdvRedirectUrl";
      function goRedirect(params) {
        var q = Object.keys(params).map(function (k) {
          return encodeURIComponent(k) + "=" + encodeURIComponent(params[k]);
        }).join("&");
        window.location.href = redirect + "?" + q;
      }
      try {
        var response = await PortOne.requestIdentityVerification({
          storeId: "$_kPortOneStoreId",
          identityVerificationId: "$idvId",
          channelKey: "$_kIdvChannelKey",
          redirectUrl: redirect,
          bypass: { inicis_unified: { flgFixedUser: "N" } }
        });
        // 모바일에선 보통 redirectUrl로 이동해 여기 도달하지 않지만, 일부 환경에서
        // 결과가 바로 반환되면 동일하게 redirect 경로로 넘겨 처리해요.
        if (response) {
          if (response.code) {
            goRedirect({ code: response.code, message: response.message || "본인인증에 실패했어요." });
          } else {
            goRedirect({ identityVerificationId: response.identityVerificationId || "$idvId" });
          }
        }
      } catch (e) {
        goRedirect({ code: "ERROR", message: (e && e.message) ? e.message : "본인인증 창을 불러오지 못했어요." });
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
    // code가 있으면 실패/취소.
    if (code != null && code.trim().isNotEmpty) {
      final message = params['message'];
      _finish(IdentityVerificationResult(
        success: false,
        message: (message == null || message.trim().isEmpty) ? '본인인증이 취소되었어요.' : message,
      ));
      return;
    }

    final idvId = params['identityVerificationId'];
    if (idvId == null || idvId.trim().isEmpty) {
      _finish(const IdentityVerificationResult(success: false, message: '본인인증 정보를 확인하지 못했어요.'));
      return;
    }

    setState(() => _confirming = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('confirmIdentityVerification')
          .call<Map<String, dynamic>>(<String, dynamic>{'identityVerificationId': idvId});
      final data = Map<String, dynamic>.from(result.data as Map);
      _finish(IdentityVerificationResult(success: true, name: data['name']?.toString()));
    } on FirebaseFunctionsException catch (e) {
      _finish(IdentityVerificationResult(success: false, message: e.message ?? '본인인증 검증에 실패했어요.'));
    } catch (_) {
      _finish(const IdentityVerificationResult(
        success: false,
        message: '본인인증 확인 중 오류가 발생했어요. 잠시 후 다시 시도해주세요.',
      ));
    }
  }

  void _finish(IdentityVerificationResult result) {
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
        title: const Text('본인인증', style: TextStyle(fontWeight: FontWeight.w800)),
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
                    _confirming ? '본인인증을 확인하고 있어요…' : '본인인증 창을 불러오는 중…',
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
