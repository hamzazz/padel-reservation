import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('DefaultFirebaseOptions not configured for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAYoPPm0URQX3IIsPFWMbi31jdQObpzsrM',
    authDomain: 'padel-club-maroc.firebaseapp.com',
    projectId: 'padel-club-maroc',
    storageBucket: 'padel-club-maroc.firebasestorage.app',
    messagingSenderId: '621755783134',
    appId: '1:621755783134:web:c88ba95e5aad5a7c9e6f4f',
    measurementId: 'G-EWF89S5HWR',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBYVSblXbCYYvQwoDN_hxdGxYYDl6mTqzU',
    appId: '1:621755783134:android:ba99979cb1d176f19e6f4f',
    messagingSenderId: '621755783134',
    projectId: 'padel-club-maroc',
    storageBucket: 'padel-club-maroc.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBYVSblXbCYYvQwoDN_hxdGxYYDl6mTqzU',
    appId: '1:621755783134:ios:ba99979cb1d176f19e6f4f',
    messagingSenderId: '621755783134',
    projectId: 'padel-club-maroc',
    storageBucket: 'padel-club-maroc.firebasestorage.app',
  );
}
