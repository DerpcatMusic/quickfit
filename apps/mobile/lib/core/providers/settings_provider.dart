import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/settings_service.dart';

class SettingsNotifier extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() async {
    return SettingsService.instance.load();
  }

  Future<void> saveSettings(UserSettings settings) async {
    await SettingsService.instance.update(settings);
    state = AsyncValue.data(settings);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, UserSettings>(SettingsNotifier.new);
