import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Replace the placeholder values with the real configuration that
/// `flutterfire configure` generates for your Firebase project.
///
/// If you already ran the command, copy the generated values here so the app
/// can initialize Firebase on every supported platform without additional
/// manual setup.
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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAz3KzU5WakWjJqLLCQmWP02ie8cjnI2b4',
    appId: '1:793369279126:web:efb329e6a9ea7b9ada20b7',
    messagingSenderId: '793369279126',
    projectId: 'rendivo-9d606',
    authDomain: 'rendivo-9d606.firebaseapp.com',
    databaseURL: 'https://rendivo-9d606-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'rendivo-9d606.firebasestorage.app',
    measurementId: 'G-S6CYNMZ1ME',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA0fJTZP4FaptX4q9mdiLnmGL5I5ndvDN4',
    appId: '1:793369279126:android:f633a936412ad374da20b7',
    messagingSenderId: '793369279126',
    projectId: 'rendivo-9d606',
    databaseURL: 'https://rendivo-9d606-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'rendivo-9d606.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBM05vdC2abMT4kysR-xngQ33SDao8_zM8',
    appId: '1:793369279126:ios:c68104cd4b45e9f6da20b7',
    messagingSenderId: '793369279126',
    projectId: 'rendivo-9d606',
    databaseURL: 'https://rendivo-9d606-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'rendivo-9d606.firebasestorage.app',
    iosBundleId: 'com.example.rendivoMobile',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBM05vdC2abMT4kysR-xngQ33SDao8_zM8',
    appId: '1:793369279126:ios:c68104cd4b45e9f6da20b7',
    messagingSenderId: '793369279126',
    projectId: 'rendivo-9d606',
    databaseURL: 'https://rendivo-9d606-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'rendivo-9d606.firebasestorage.app',
    iosBundleId: 'com.example.rendivoMobile',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAz3KzU5WakWjJqLLCQmWP02ie8cjnI2b4',
    appId: '1:793369279126:web:bbd16fbcb0e1b5a6da20b7',
    messagingSenderId: '793369279126',
    projectId: 'rendivo-9d606',
    authDomain: 'rendivo-9d606.firebaseapp.com',
    databaseURL: 'https://rendivo-9d606-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'rendivo-9d606.firebasestorage.app',
    measurementId: 'G-1MLHBRQKR1',
  );

}