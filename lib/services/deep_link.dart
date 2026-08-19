import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 공유 링크로 들어왔을 때 열어줄 대상의 종류입니다.
enum DeepLinkType { product, profile }

/// 파싱된 딥링크 대상 정보 (상품 ID 또는 판매자 uid).
class DeepLinkTarget {
  final DeepLinkType type;
  final String id;

  const DeepLinkTarget(this.type, this.id);
}

/// 웹 결제(토스페이먼츠) 후 결제 페이지(pay.html)가 앱으로 돌아올 때 붙여주는
/// 결과 정보예요.
///  - 토스:   /?pmtDone=1&pid=...&paymentKey=...&orderId=...&amount=...(&code=...)
///  - 구 포트원(보존): /?pmtDone=1&pid=...&paymentId=...(&code=...)
class PendingPayment {
  final String? paymentId;   // 구 포트원 결제번호 (보존 — 롤백용)
  final String? paymentKey;  // 토스 결제 키
  final String? orderId;     // 토스 주문번호
  final int? amount;         // 토스 결제 금액(원)
  final String? productId;
  final String? errorCode;
  final String? errorMessage;

  const PendingPayment({
    this.paymentId,
    this.paymentKey,
    this.orderId,
    this.amount,
    this.productId,
    this.errorCode,
    this.errorMessage,
  });

  /// 토스 결제 복귀인지(=paymentKey가 있는지) 판단해요.
  bool get isToss => paymentKey != null && paymentKey!.trim().isNotEmpty;

  bool get isFailure {
    if (errorCode != null && errorCode!.trim().isNotEmpty) return true;
    final hasToss = paymentKey != null && paymentKey!.trim().isNotEmpty;
    final hasPortone = paymentId != null && paymentId!.trim().isNotEmpty;
    // 토스(paymentKey)도 포트원(paymentId)도 없으면 실패로 간주해요.
    return !hasToss && !hasPortone;
  }
}

/// 웹 본인인증(포트원 통합인증) 후 인증 페이지(verify.html)가 앱으로 돌아올 때
/// 붙여주는 결과 정보예요. redirectUrl 예: /?idvDone=1&identityVerificationId=...(&code=...)
class PendingIdentity {
  final String? identityVerificationId;
  final String? errorCode;
  final String? errorMessage;

  const PendingIdentity({
    this.identityVerificationId,
    this.errorCode,
    this.errorMessage,
  });

  bool get isFailure =>
      (errorCode != null && errorCode!.trim().isNotEmpty) ||
      identityVerificationId == null ||
      identityVerificationId!.trim().isEmpty;
}

/// 앱이 처음 열릴 때의 브라우저 주소(예: https://duckauction.com/products/abc123)를
/// 확인해서, 스플래시 화면의 기본 흐름이 끝난 뒤 어떤 화면을 추가로 열어줄지
/// 기억해두는 아주 작은 헬퍼입니다.
///
/// 딥링크 대상이 없으면(=평소처럼 그냥 duckauction.com으로 접속한 경우) 아무
/// 동작도 하지 않으므로, 기존 로그인/스플래시 흐름에는 영향을 주지 않습니다.
class DeepLink {
  DeepLink._();

  /// MaterialApp의 navigatorKey로 등록해서 씁니다. 스플래시 화면 자신의
  /// context/Navigator에 기대지 않고도 딥링크 화면을 안전하게 push할 수 있게
  /// 해줍니다(스플래시가 pushReplacement로 사라진 뒤에도 안전).
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static DeepLinkTarget? _pending;
  static PendingPayment? _pendingPayment;
  static PendingIdentity? _pendingIdentity;

  /// main()에서 앱 시작 시 딱 한 번 호출합니다.
  static void captureInitial() {
    if (!kIsWeb) return;
    try {
      // 웹 결제 후 돌아온 경우(pay.html → /?pmtDone=1&...)를 먼저 캡처해요.
      final q = Uri.base.queryParameters;
      if (q['pmtDone'] == '1') {
        _pendingPayment = PendingPayment(
          paymentId: q['paymentId'],
          paymentKey: q['paymentKey'],
          orderId: q['orderId'],
          amount: int.tryParse(q['amount'] ?? ''),
          productId: q['pid'],
          errorCode: q['code'],
          errorMessage: q['message'],
        );
      }

      // 웹 본인인증 후 돌아온 경우(verify.html → /?idvDone=1&...)도 캡처해요.
      if (q['idvDone'] == '1') {
        _pendingIdentity = PendingIdentity(
          identityVerificationId: q['identityVerificationId'],
          errorCode: q['code'],
          errorMessage: q['message'],
        );
      }

      final segments = Uri.base.pathSegments.where((s) => s.trim().isNotEmpty).toList();
      if (segments.length < 2) return;

      final id = segments[1].trim();
      if (id.isEmpty) return;

      if (segments[0] == 'products') {
        _pending = DeepLinkTarget(DeepLinkType.product, id);
      } else if (segments[0] == 'profile') {
        _pending = DeepLinkTarget(DeepLinkType.profile, id);
      }
    } catch (e) {
      // 주소 파싱이 실패해도 앱은 평소처럼 시작되어야 하므로 조용히 무시합니다.
      // ignore: avoid_print
      print('DeepLink parse failed: $e');
    }
  }

  /// 대기 중인 딥링크가 있으면 반환하고, 다시 조회되지 않도록 비웁니다.
  static DeepLinkTarget? consumePending() {
    final value = _pending;
    _pending = null;
    return value;
  }

  /// 대기 중인 웹 결제 결과가 있는지(소모하지 않고) 확인합니다.
  /// 스플래시에서 "결제 후 복귀"인지 미리 알아 로딩을 건너뛰는 데 씁니다.
  static bool get hasPendingPayment => _pendingPayment != null;

  /// 대기 중인 웹 결제 결과가 있으면 반환하고, 다시 조회되지 않도록 비웁니다.
  static PendingPayment? consumePendingPayment() {
    final value = _pendingPayment;
    _pendingPayment = null;
    return value;
  }

  /// 대기 중인 웹 본인인증 결과가 있는지(소모하지 않고) 확인합니다.
  static bool get hasPendingIdentity => _pendingIdentity != null;

  /// 대기 중인 웹 본인인증 결과가 있으면 반환하고, 다시 조회되지 않도록 비웁니다.
  static PendingIdentity? consumePendingIdentity() {
    final value = _pendingIdentity;
    _pendingIdentity = null;
    return value;
  }
}
