import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

  runApp(const DuckAuctionApp());
}

class DuckAuctionApp extends StatelessWidget {
  const DuckAuctionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '덕옥션',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        fontFamily: 'Pretendard',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF334155),
          primary: const Color(0xFF334155),
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
            backgroundColor: const Color(0xFF334155),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
