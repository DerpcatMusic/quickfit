import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class UserSettings {
  const UserSettings({
    required this.notificationsEnabled,
    required this.regularJobAlerts,
    required this.sosJobAlerts,
    required this.languageCode,
  });

  final bool notificationsEnabled;
  final bool regularJobAlerts;
  final bool sosJobAlerts;
  final String languageCode;

  UserSettings copyWith({
    bool? notificationsEnabled,
    bool? regularJobAlerts,
    bool? sosJobAlerts,
    String? languageCode,
  }) {
    return UserSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      regularJobAlerts: regularJobAlerts ?? this.regularJobAlerts,
      sosJobAlerts: sosJobAlerts ?? this.sosJobAlerts,
      languageCode: languageCode ?? this.languageCode,
    );
  }

  static const UserSettings defaults = UserSettings(
    notificationsEnabled: true,
    regularJobAlerts: true,
    sosJobAlerts: true,
    languageCode: 'en',
  );
}

class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  UserSettings _current = UserSettings.defaults;
  bool _loaded = false;

  UserSettings get current => _current;

  Future<UserSettings> load() async {
    if (_loaded) return _current;
    final prefs = await SharedPreferences.getInstance();
    _current = UserSettings(
      notificationsEnabled: prefs.getBool(StorageKeys.notificationsEnabled) ??
          UserSettings.defaults.notificationsEnabled,
      regularJobAlerts: prefs.getBool(StorageKeys.regularJobAlerts) ??
          UserSettings.defaults.regularJobAlerts,
      sosJobAlerts: prefs.getBool(StorageKeys.sosJobAlerts) ??
          UserSettings.defaults.sosJobAlerts,
      languageCode: prefs.getString(StorageKeys.languageCode) ??
          UserSettings.defaults.languageCode,
    );
    _loaded = true;
    return _current;
  }

  Future<void> update(UserSettings settings) async {
    _current = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        StorageKeys.notificationsEnabled, settings.notificationsEnabled);
    await prefs.setBool(
        StorageKeys.regularJobAlerts, settings.regularJobAlerts);
    await prefs.setBool(StorageKeys.sosJobAlerts, settings.sosJobAlerts);
    await prefs.setString(StorageKeys.languageCode, settings.languageCode);
  }
}
