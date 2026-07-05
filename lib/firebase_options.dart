// File generated manually (without flutterfire_cli, due to a local
// authentication issue with the Firebase CLI) from the values contained in
// android/app/google-services.json.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// This project currently only configures Android, per the chosen platform
/// scope for this app. If iOS/web support is added later, this file should
/// be regenerated (ideally via `flutterfire configure` once available, or
/// extended manually with the equivalent values from the Firebase Console).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'this app currently only targets Android.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'this app currently only targets Android.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCxDNjPw6LKqaGNTIHnj6FVwfI2orDW5Ao',
    appId: '1:312497458452:android:4e91d2ea203a6b12b50601',
    messagingSenderId: '312497458452',
    projectId: 'message-ko',
    storageBucket: 'message-ko.firebasestorage.app',
  );
}
