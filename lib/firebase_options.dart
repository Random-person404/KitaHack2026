import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDPqABTJedcN725i6zm3nsJqMlUSaaknqc', 
    appId: '1:173688024632:android:adc8eebe8bd5e3b03700cd', 
    messagingSenderId: '173688024632',
    projectId: 'asl-translator-448f0',
     storageBucket: 'asl-translator-448f0.firebasestorage.app', 
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDPqABTJedcN725i6zm3nsJqMlUSaaknqc',
    appId: '1:173688024632:android:adc8eebe8bd5e3b03700cd', 
    messagingSenderId: '173688024632',
    projectId: 'asl-translator-448f0',
    authDomain: 'asl-translator-448f0.firebaseapp.com',
    storageBucket: 'asl-translator-448f0.firebasestorage.app', 
  );
}