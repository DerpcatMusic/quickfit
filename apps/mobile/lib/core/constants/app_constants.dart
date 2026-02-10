// Flutter core constants
// lib/core/constants/app_constants.dart

class AppConstants {
  static const String appName = 'Quickfit';
  static const String convexUrl = String.fromEnvironment(
    'CONVEX_URL',
    defaultValue: 'https://quick-otter-489.convex.cloud',
  );

  // SOS threshold in hours
  static const double sosThresholdHours = 3.0;
  static const double sosBoostPercentage = 15.0;

  // Default instructor radius in km
  static const double defaultRadiusKm = 5.0;
  static const double minRadiusKm = 1.0;
  static const double maxRadiusKm = 50.0;

  // Pagination
  static const int jobsPageSize = 50;

  // Cache durations
  static const Duration shortCacheDuration = Duration(minutes: 5);
  static const Duration longCacheDuration = Duration(hours: 1);
}

class StorageKeys {
  static const String fcmToken = 'fcm_token';
  static const String onboardingComplete = 'onboarding_complete';
  static const String userRole = 'user_role';
  static const String lastLocation = 'last_location';
  static const String notificationsEnabled = 'settings_notifications_enabled';
  static const String regularJobAlerts = 'settings_regular_job_alerts';
  static const String sosJobAlerts = 'settings_sos_job_alerts';
  static const String languageCode = 'settings_language_code';
}
