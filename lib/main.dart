import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/analytics_service.dart';
import 'services/deep_link.dart';
import 'services/push_notification_service.dart';
import 'services/session_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // 해시(#) 없는 깔끔한 주소를 쓰게 하고(예: duckauction.com/products/abc123),
    // 그 주소를 상품/프로필 공유 딥링크 대상으로 미리 파싱해둡니다.
    usePathUrlStrategy();
    DeepLink.captureInitial();
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 화면(Flutter 위젯 빌드 등)에서 발생한 예외를 Analytics 이벤트로 남겨서
  // 최소한의 오류 가시성을 확보합니다. 콘솔에도 그대로 출력해 개발 중에는
  // 기존처럼 바로 확인할 수 있습니다.
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    originalOnError?.call(details);
    AnalyticsService.logError('flutter_error', details.exception, details.stack);
  };

  // 화면 빌드 바깥(비동기 콜백 등)에서 발생한, Flutter가 못 잡는 예외를 잡습니다.
  PlatformDispatcher.instance.onError = (error, stack) {
    AnalyticsService.logError('platform_error', error, stack);
    return true;
  };

  // Flutter 웹을 chrome으로 실행할 때도 로그인 세션을 local storage에 남깁니다.
  // 단, flutter clean을 하면 Flutter가 쓰는 임시 Chrome 프로필도 지워질 수 있으니
  // 개발 중 자동로그인을 확인할 때는 run_chrome_persistent.bat로 실행하세요.
  if (kIsWeb) {
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    } catch (_) {
      // Android/iOS/설정 타이밍 차이에서는 무시해도 됩니다.
    }
  }

  // 로그인된 사용자가 있을 때마다(첫 실행 시 자동 로그인 복원 포함) 푸시 알림
  // 등록을 시도합니다. initialize() 내부에서 중복 호출/웹 환경/권한 거부를
  // 알아서 처리하므로 여기서는 그냥 매번 호출해도 안전합니다.
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      unawaited(PushNotificationService.instance.initialize());
      // 동일 계정 중복 로그인 방지: 이 기기를 활성 세션으로 등록하고, 다른 기기가
      // 같은 계정으로 로그인하면 이 기기는 자동 로그아웃돼요.
      unawaited(SessionGuard.instance.start(user.uid));
    } else {
      unawaited(SessionGuard.instance.stop());
    }
  });

  runApp(const DuckAuctionApp());
}

class DuckAuctionApp extends StatelessWidget {
  const DuckAuctionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: DeepLink.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: '덕옥션',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        fontFamily: 'Pretendard',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16305C),
          primary: const Color(0xFF16305C),
          secondary: const Color(0xFFF97316),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: Color(0xFF111827),
          elevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF16305C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
