// Background Sync Service - Ultra-lightweight for urgent notifications
// lib/core/services/background_sync_service.dart
//
// This service runs in the background and ONLY:
// 1. Maintains FCM connection for push notifications
// 2. Syncs offline queue when app is backgrounded
// 3. Minimal battery usage - no location tracking

import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'connectivity_plus/connectivity_plus.dart';
import 'hive_service.dart';
import 'offline_queue_manager.dart';
import 'notification_service.dart';

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
    await service.invoke('stop');
    _isRunning = false;
  }

  /// Check if service is running
  bool get isRunning => _isRunning;
}

/// Background entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
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

  // Listen for connectivity changes
  final connectivity = Connectivity();
  connectivity.onConnectivityChanged.listen((results) {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    if (result != ConnectivityResult.none) {
      // Came online - trigger sync
      _syncPendingMutations();
    }
  });

  // Periodic sync every 5 minutes (lightweight)
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    await _syncPendingMutations();
  });

  // Initial sync
  await _syncPendingMutations();
}

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  await HiveService().init();
  await _syncPendingMutations();
  return true;
}

/// Sync pending mutations from offline queue
Future<void> _syncPendingMutations() async {
  try {
    final pending = HiveService().getPendingMutations();
    if (pending.isEmpty) return;

    // Check connectivity
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    if (results.isEmpty || results.first == ConnectivityResult.none) {
      return; // No connection, skip
    }

    // Process each pending mutation
    for (final mutation in pending) {
      if (mutation.status == 'syncing' || mutation.status == 'completed') {
        continue;
      }

      // Update status
      mutation.status = 'syncing';
      await mutation.save();

      // TODO: Execute mutation via Convex
      // This would need ConvexClient initialized in background
      // For now, just mark for foreground sync

      mutation.status = 'pending';
      await mutation.save();
    }
  } catch (e) {
    print('Background sync error: $e');
  }
}
