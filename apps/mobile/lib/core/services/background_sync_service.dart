// Background Sync Service - Ultra-lightweight for urgent notifications
// lib/core/services/background_sync_service.dart
//
// This service runs in the background and ONLY:
// 1. Maintains FCM connection for push notifications
// 2. Syncs offline queue when app is backgrounded
// 3. Minimal battery usage - no location tracking

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:quickfit/firebase_options.dart';
import '../constants/app_constants.dart';
import 'hive_service.dart';
import 'offline_mutation_runner.dart';

/// Ultra-lightweight background service
/// Focused on receiving urgent notifications for last-minute replacements
class BackgroundSyncService {
  static final BackgroundSyncService _instance = BackgroundSyncService._();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._();

  bool _isRunning = false;

  /// Initialize the background service
  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true, // Keeps FCM connection alive
        notificationChannelId: 'quickfit_bg',
        initialNotificationTitle: 'QuickFit Active',
        initialNotificationContent: 'Waiting for urgent job notifications',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    _isRunning = true;
  }

  /// Start the service
  Future<bool> startService() async {
    final service = FlutterBackgroundService();
    return await service.startService();
  }

  /// Stop the service
  Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
    _isRunning = false;
  }

  /// Check if service is running
  bool get isRunning => _isRunning;
}

/// Background entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  await _ensureFirebaseInitialized();
  await _ensureConvexInitialized();

  // Initialize Hive for offline queue
  await HiveService().init();

  // Dart requires this for background execution
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stop').listen((event) {
    service.stopSelf();
  });

  // Listen for connectivity changes (event-based sync)
  final connectivity = Connectivity();
  connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
    if (results.isNotEmpty &&
        results.any((r) => r != ConnectivityResult.none)) {
      _syncPendingMutations();
    }
  });

  // Initial sync
  await _syncPendingMutations();
}

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  await _ensureFirebaseInitialized();
  await _ensureConvexInitialized();
  await HiveService().init();
  await _syncPendingMutations();
  return true;
}

/// Sync pending mutations from offline queue
Future<void> _syncPendingMutations() async {
  try {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await ConvexClient.instance.setAuthWithRefresh(
      fetchToken: () async {
        return await user.getIdToken();
      },
    );

    // Check connectivity
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    if (results.isEmpty || !results.any((r) => r != ConnectivityResult.none)) {
      return; // No connection, skip
    }

    await OfflineMutationRunner.runPending();
  } catch (e, stack) {
    developer.log(
      'Background sync error',
      name: 'quickfit.sync',
      error: e,
      stackTrace: stack,
    );
  }
}

Future<void> _ensureFirebaseInitialized() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
}

Future<void> _ensureConvexInitialized() async {
  try {
    await ConvexClient.initialize(
      const ConvexConfig(
        deploymentUrl: AppConstants.convexUrl,
        clientId: 'quickfit-mobile-bg',
      ),
    );
  } catch (_) {}
}
