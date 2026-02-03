// Centralized API Keys configuration
// lib/core/config/api_keys.dart

import 'api_keys_local.dart' if (dart.library.io) 'api_keys_local_stub.dart';

class ApiKeys {
  ApiKeys._();

  // ==============================================================================
  // GOOGLE MAPS
  // ==============================================================================

  // ANDROID:
  // Copy this key to android/app/src/main/AndroidManifest.xml
  // Inside the <application> tag:
  // <meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_KEY_HERE"/>
  static const String googleMapsAndroid =
      kLocalMapsAndroid ?? 'YOUR_ANDROID_API_KEY';

  // IOS:
  // Copy this key to lines in ios/Runner/AppDelegate.swift (if using GoogleMaps on iOS)
  // GMSServices.provideAPIKey("YOUR_KEY_HERE")
  static const String googleMapsIos = kLocalMapsIos ?? 'YOUR_IOS_API_KEY';

  // WEB:
  // Copy this key to web/index.html
  // <script src="https://maps.googleapis.com/maps/api/js?key=YOUR_KEY_HERE"></script>
  static const String googleMapsWeb = kLocalMapsWeb ?? 'YOUR_WEB_API_KEY';

  // ==============================================================================
  // GOOGLE SIGN IN
  // ==============================================================================

  // WEB CLIENT ID:
  // Copy this key to web/index.html
  // <meta name="google-signin-client_id" content="YOUR_CLIENT_ID_HERE">
  static const String googleSignInWebClientId = kLocalGoogleClientId ??
      '150915747323-ki5cdfrdb5fnmcq09rtpb2itu0evh7gc.apps.googleusercontent.com';

  // iOS/macOS Client ID is usually handled via GoogleService-Info.plist
  // Android is handled via google-services.json
}
