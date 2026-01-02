// File generated manually for WFL Animator Firebase project
// Project: wflanimator

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
    apiKey: 'AIzaSyDsOQEfSMSwzreMVh5P_CpFTkV7i0RgT_U',
    appId: '1:1056441231762:web:wflanimator',
    messagingSenderId: '1056441231762',
    projectId: 'wflanimator',
    authDomain: 'wflanimator.firebaseapp.com',
    storageBucket: 'wflanimator.firebasestorage.app',
  );

  // Windows uses web configuration
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDsOQEfSMSwzreMVh5P_CpFTkV7i0RgT_U',
    appId: '1:1056441231762:web:wflanimator',
    messagingSenderId: '1056441231762',
    projectId: 'wflanimator',
    authDomain: 'wflanimator.firebaseapp.com',
    storageBucket: 'wflanimator.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDsOQEfSMSwzreMVh5P_CpFTkV7i0RgT_U',
    appId: '1:1056441231762:android:wflanimator',
    messagingSenderId: '1056441231762',
    projectId: 'wflanimator',
    storageBucket: 'wflanimator.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDsOQEfSMSwzreMVh5P_CpFTkV7i0RgT_U',
    appId: '1:1056441231762:ios:wflanimator',
    messagingSenderId: '1056441231762',
    projectId: 'wflanimator',
    storageBucket: 'wflanimator.firebasestorage.app',
    iosBundleId: 'com.wfl.viewer',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDsOQEfSMSwzreMVh5P_CpFTkV7i0RgT_U',
    appId: '1:1056441231762:macos:wflanimator',
    messagingSenderId: '1056441231762',
    projectId: 'wflanimator',
    storageBucket: 'wflanimator.firebasestorage.app',
    iosBundleId: 'com.wfl.viewer',
  );
}
