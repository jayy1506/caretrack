import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for CareTrack
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAxU6oxTYZyg-1tugDzEmvxwY7MOkYSEeg',
    appId: '1:636833473708:web:902e02129d37258c29eb09',
    messagingSenderId: '636833473708',
    projectId: 'caretrack-47af5',
    storageBucket: 'caretrack-47af5.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAxU6oxTYZyg-1tugDzEmvxwY7MOkYSEeg',
    appId: '1:636833473708:android:902e02129d37258c29eb09',
    messagingSenderId: '636833473708',
    projectId: 'caretrack-47af5',
    storageBucket: 'caretrack-47af5.firebasestorage.app',
  );
}
