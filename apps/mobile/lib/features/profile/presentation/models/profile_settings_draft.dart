import 'package:quickfit/core/services/settings_service.dart';

class ProfileSettingsDraft {
  const ProfileSettingsDraft({
    required this.languageCode,
    required this.notificationsEnabled,
    required this.regularJobAlerts,
    required this.sosJobAlerts,
  });

  final String languageCode;
  final bool notificationsEnabled;
  final bool regularJobAlerts;
  final bool sosJobAlerts;

  factory ProfileSettingsDraft.defaults() =>
      ProfileSettingsDraft.fromSettings(UserSettings.defaults);

  factory ProfileSettingsDraft.fromSettings(UserSettings settings) {
    return ProfileSettingsDraft(
      languageCode: settings.languageCode,
      notificationsEnabled: settings.notificationsEnabled,
      regularJobAlerts: settings.regularJobAlerts,
      sosJobAlerts: settings.sosJobAlerts,
    );
  }

  ProfileSettingsDraft copyWith({
    String? languageCode,
    bool? notificationsEnabled,
    bool? regularJobAlerts,
    bool? sosJobAlerts,
  }) {
    return ProfileSettingsDraft(
      languageCode: languageCode ?? this.languageCode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      regularJobAlerts: regularJobAlerts ?? this.regularJobAlerts,
      sosJobAlerts: sosJobAlerts ?? this.sosJobAlerts,
    );
  }

  UserSettings toSettings(UserSettings base) {
    return base.copyWith(
      languageCode: languageCode,
      notificationsEnabled: notificationsEnabled,
      regularJobAlerts: regularJobAlerts,
      sosJobAlerts: sosJobAlerts,
    );
  }
}
