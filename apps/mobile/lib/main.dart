// Main entry point
// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:google_sign_in/google_sign_in.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'core/services/notification_service.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Handle background notification
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Silence verbose WebConvexClient logs that overwhelm the console on Web.
  // This is a robust way to hide logs from third-party packages that don't
  // provide a built-in silence flag.
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null && message.contains('[WebConvexClient]')) {
      return;
    }
    originalDebugPrint(message, wrapWidth: wrapWidth);
  };

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Google Sign-In
  // Note: No explicit initialization needed for mobile on version 7.x unless using specific scopes

  // Setup FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize notifications
  await NotificationService.instance.initialize();

  runApp(
    const ProviderScope(
      child: QuickfitApp(),
    ),
  );
}
