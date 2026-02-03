// FCM Notification Service
// lib/core/services/notification_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

import '../constants/app_constants.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final _notificationController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onNotification => _notificationController.stream;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    // Request permissions
    await _requestPermissions();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get FCM token
    await _getFcmToken();

    // Listen for token refresh
    _fcm.onTokenRefresh.listen(_onTokenRefresh);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      log.i('FCM: User granted permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      log.i('FCM: User granted provisional permission');
    } else {
      log.w('FCM: User declined permission');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create notification channel for Android
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _createAndroidChannels();
    }
  }

  Future<void> _createAndroidChannels() async {
    const sosChannel = AndroidNotificationChannel(
      'sos_jobs',
      'SOS Jobs',
      description: 'Urgent job notifications for classes starting soon',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const regularChannel = AndroidNotificationChannel(
      'regular_jobs',
      'Job Notifications',
      description: 'New job opportunities in your area',
      importance: Importance.high,
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(sosChannel);
    await androidPlugin?.createNotificationChannel(regularChannel);
  }

  Future<void> _getFcmToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      if (_fcmToken != null) {
        await _saveToken(_fcmToken!);
        log.i('FCM Token: $_fcmToken');
      }
    } catch (e) {
      log.e('Failed to get FCM token: $e');
    }
  }

  void _onTokenRefresh(String token) async {
    _fcmToken = token;
    await _saveToken(token);
    log.i('FCM Token refreshed: $token');
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.fcmToken, token);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    log.i('Received foreground message: ${message.messageId}');
    _notificationController.add(message);

    // Show local notification
    _showLocalNotification(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    log.i('Notification tapped: ${message.messageId}');
    _notificationController.add(message);

    // Handle navigation based on notification data
    final data = message.data;
    final type = data['type'];
    final jobId = data['jobId'];

    if (type == 'new_job' && jobId != null) {
      // Navigate to job details
      // This will be handled by the app router
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    log.i('Local notification tapped: ${response.payload}');
    // Handle local notification tap
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final isSos = message.data['isSos'] == 'true';
    final channelId = isSos ? 'sos_jobs' : 'regular_jobs';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      isSos ? 'SOS Jobs' : 'Job Notifications',
      importance: isSos ? Importance.max : Importance.high,
      priority: isSos ? Priority.max : Priority.high,
      color: isSos ? const ui.Color(0xFFDC2626) : const ui.Color(0xFF6366F1),
      ticker: notification.title,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['jobId'],
    );
  }

  // Subscribe to topic (e.g., category or area)
  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
    log.i('Subscribed to topic: $topic');
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
    log.i('Unsubscribed from topic: $topic');
  }

  void dispose() {
    _notificationController.close();
  }
}
