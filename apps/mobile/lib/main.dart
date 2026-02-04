// Main entry point
// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:convex_flutter/convex_flutter.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'core/services/notification_service.dart';
import 'core/constants/app_constants.dart';

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

  // Core initialization that must happen before runApp
  await Future.wait([
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ),
    ConvexClient.initialize(
      const ConvexConfig(
        deploymentUrl: AppConstants.convexUrl,
        clientId: 'quickfit-mobile-1.0',
      ),
    ),
  ]);

  // Non-blocking background initialization
  // We fire-and-forget these so they don't block the initial render.
  // Notification permissions can take 10s+ if the user is slow to click "Allow."
  NotificationService.instance.initialize().ignore();

  // Setup FCM background handler (non-blocker)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    const ProviderScope(
      child: QuickfitApp(),
    ),
  );
}
