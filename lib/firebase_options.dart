import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    throw UnsupportedError('현재는 Web 설정만 등록되어 있습니다.');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDOp_dPbWbSQyWaqcoHQAzruVbAQn0GC0A',
    authDomain: 'duck-auction.firebaseapp.com',
    projectId: 'duck-auction',
    storageBucket: 'duck-auction.firebasestorage.app',
    messagingSenderId: '203119332761',
    appId: '1:203119332761:web:b0f1c3b5317e512f189708',
    measurementId: 'G-7K5KP3XC4H',
  );
}
