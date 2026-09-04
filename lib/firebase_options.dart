import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDryf9Gtq0WpKObkZg9c1rD9geIrYDpLro',
    appId: '1:886946341961:web:1c36aacef0b57c23d3cb98',
    messagingSenderId: '886946341961',
    projectId: 'ff-arena-31e36',
    authDomain: 'ff-arena-31e36.firebaseapp.com',
    storageBucket: 'ff-arena-31e36.firebasestorage.app',
    measurementId: 'G-VVF8X5QJ2N',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAqjsUw05_jZtraApJhitFov1paaFzj6Mg',
    appId: '1:886946341961:android:0ad0e6d7b2f36fd6d3cb98',
    messagingSenderId: '886946341961',
    projectId: 'ff-arena-31e36',
    storageBucket: 'ff-arena-31e36.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDryf9Gtq0WpKObkZg9c1rD9geIrYDpLro',
    appId: '1:886946341961:ios:your_ios_app_id',
    messagingSenderId: '886946341961',
    projectId: 'ff-arena-31e36',
    storageBucket: 'ff-arena-31e36.firebasestorage.app',
    iosBundleId: 'com.ffarena.ff_arena',
  );
}
