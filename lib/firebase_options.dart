// Firebase configuration for DharmaAI.
// Web is configured now; Android will be added to the SAME Firebase project
// (dharmaai-f0078) when the mobile app is built — re-run `flutterfire configure`
// or add the android block here at that time.
//
// NOTE: these values are NOT secrets — Firebase web config is public and meant
// to be embedded in the client (like the Supabase anon key).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Firebase is not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCZQAAa0UQWOA6owZm-adBirUJcBdFZZUg',
    appId: '1:494796756772:web:d3c8c1840472fc816a05b1',
    messagingSenderId: '494796756772',
    projectId: 'dharmaai-f0078',
    authDomain: 'dharmaai-f0078.firebaseapp.com',
    storageBucket: 'dharmaai-f0078.firebasestorage.app',
    measurementId: 'G-HW138CH39L',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBpZc_lUHhod6W-zpzoxVTYZjce2rEfXmc',
    appId: '1:494796756772:android:488070190c1d64306a05b1',
    messagingSenderId: '494796756772',
    projectId: 'dharmaai-f0078',
    storageBucket: 'dharmaai-f0078.firebasestorage.app',
  );
}
