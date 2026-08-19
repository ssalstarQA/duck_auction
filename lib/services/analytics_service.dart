import 'package:firebase_analytics/firebase_analytics.dart';

/// Firebase Analytics 래퍼입니다.
///
/// 참고: firebase_crashlytics는 웹을 지원하지 않아서(Android/iOS/macOS 전용),
/// 지금처럼 웹으로 개발/운영 중인 단계에서는 추가하면 오히려 웹 빌드가 깨질 수
/// 있어 넣지 않았습니다. 대신 전역 에러를 Analytics 이벤트로 기록해서 최소한의
/// 오류 가시성을 확보합니다. 나중에 앱스토어/플레이스토어용 모바일 빌드를
/// 시작하면 그때 firebase_crashlytics를 추가하는 걸 권장해요.
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics instance = FirebaseAnalytics.instance;

  /// 전역 에러 핸들러(main.dart)에서 호출합니다.
  static Future<void> logError(String source, Object error, [StackTrace? stack]) async {
    try {
      final message = error.toString();
      await instance.logEvent(
        name: 'app_error',
        parameters: {
          'source': source,
          'message': message.length > 100 ? message.substring(0, 100) : message,
        },
      );
    } catch (_) {
      // 로깅 자체가 실패해도 앱 동작에는 영향을 주지 않습니다.
    }
  }

  /// 화면 이동, 주요 액션 등 원하는 곳에서 자유롭게 호출해서 쓸 수 있는
  /// 범용 이벤트 로깅 헬퍼입니다.
  static Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    try {
      await instance.logEvent(name: name, parameters: parameters);
    } catch (_) {
      // ignore
    }
  }
}
