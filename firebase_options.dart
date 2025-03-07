// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'

    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDJXWXXbZ96rL9dKnlPTOoaBdSU-QlXK7A',
    appId: '1:390743510536:web:8d8968892004f79a604bbd',
    messagingSenderId: '390743510536',
    projectId: 'loanscope-9f38b',
    authDomain: 'loanscope-9f38b.firebaseapp.com',
    storageBucket: 'loanscope-9f38b.firebasestorage.app',
    measurementId: 'G-LN4794ZBLW',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBeXAk0Epi7wlmj_q19TkTl8IDlDdmsQRQ',
    appId: '1:390743510536:android:f086c63d9a1d767b604bbd',
    messagingSenderId: '390743510536',
    projectId: 'loanscope-9f38b',
    storageBucket: 'loanscope-9f38b.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCfbowt6S498XeJCJ8hQXvKUIlWgAC-NYs',
    appId: '1:390743510536:ios:ca9258c6bcab08b5604bbd',
    messagingSenderId: '390743510536',
    projectId: 'loanscope-9f38b',
    storageBucket: 'loanscope-9f38b.firebasestorage.app',
    iosBundleId: 'com.example.loanscope',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCfbowt6S498XeJCJ8hQXvKUIlWgAC-NYs',
    appId: '1:390743510536:ios:ca9258c6bcab08b5604bbd',
    messagingSenderId: '390743510536',
    projectId: 'loanscope-9f38b',
    storageBucket: 'loanscope-9f38b.firebasestorage.app',
    iosBundleId: 'com.example.loanscope',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDJXWXXbZ96rL9dKnlPTOoaBdSU-QlXK7A',
    appId: '1:390743510536:web:2fd7e990fe05df8f604bbd',
    messagingSenderId: '390743510536',
    projectId: 'loanscope-9f38b',
    authDomain: 'loanscope-9f38b.firebaseapp.com',
    storageBucket: 'loanscope-9f38b.firebasestorage.app',
    measurementId: 'G-357BZ58S7E',
  );
}
