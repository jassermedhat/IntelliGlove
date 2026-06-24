// Generated for the approved IntelliGlove Firebase project.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return web;
      default:
        throw UnsupportedError(
          'Firebase is not configured for $defaultTargetPlatform.',
        );
    }
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyD_8YUYaZhuj9KnkYaNtAE1SqD-fK_TVYE',
    appId: '1:807420369780:web:c76af5595d62477859ea21',
    messagingSenderId: '807420369780',
    projectId: 'intelligent-glove-asl-33-da1aa',
    authDomain: 'intelligent-glove-asl-33-da1aa.firebaseapp.com',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyDcUHhTudyhKrv-NjKpmQB6bOoJyQhkvp4',
    appId: '1:807420369780:android:75df106ca75b123d59ea21',
    messagingSenderId: '807420369780',
    projectId: 'intelligent-glove-asl-33-da1aa',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyAqlE_l_1qnF1UlBK2c3hk3xiUPGJ5QZc0',
    appId: '1:807420369780:ios:aa49434c44397e8659ea21',
    messagingSenderId: '807420369780',
    projectId: 'intelligent-glove-asl-33-da1aa',
    iosClientId:
        '807420369780-sk8r63o64r5fmfs20q5rcot6dv2alcib.apps.googleusercontent.com',
    iosBundleId: 'com.intelligentglove.asl',
  );
}
