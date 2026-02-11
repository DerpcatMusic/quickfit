import 'package:flutter_test/flutter_test.dart';
import 'package:quickfit/core/services/settings_service.dart';
import 'package:quickfit/features/profile/presentation/models/profile_settings_draft.dart';

void main() {
  test('fromSettings maps persisted user settings into draft', () {
    const settings = UserSettings(
      notificationsEnabled: false,
      regularJobAlerts: true,
      sosJobAlerts: false,
      languageCode: 'he',
    );

    final draft = ProfileSettingsDraft.fromSettings(settings);

    expect(draft.notificationsEnabled, settings.notificationsEnabled);
    expect(draft.regularJobAlerts, settings.regularJobAlerts);
    expect(draft.sosJobAlerts, settings.sosJobAlerts);
    expect(draft.languageCode, settings.languageCode);
  });

  test('toSettings applies draft updates on top of merged base settings', () {
    const loaded = UserSettings(
      notificationsEnabled: false,
      regularJobAlerts: true,
      sosJobAlerts: true,
      languageCode: 'en',
    );

    final merged = loaded.copyWith(
      notificationsEnabled: true,
      regularJobAlerts: false,
      languageCode: 'he',
    );

    final draft = ProfileSettingsDraft.fromSettings(merged).copyWith(
      sosJobAlerts: false,
    );

    final applied = draft.toSettings(merged);

    expect(applied.notificationsEnabled, true);
    expect(applied.regularJobAlerts, false);
    expect(applied.sosJobAlerts, false);
    expect(applied.languageCode, 'he');
  });

  test('copyWith updates only targeted fields', () {
    const initial = ProfileSettingsDraft(
      languageCode: 'en',
      notificationsEnabled: true,
      regularJobAlerts: true,
      sosJobAlerts: true,
    );

    final updated = initial.copyWith(
      regularJobAlerts: false,
      languageCode: 'he',
    );

    expect(updated.notificationsEnabled, true);
    expect(updated.regularJobAlerts, false);
    expect(updated.sosJobAlerts, true);
    expect(updated.languageCode, 'he');
  });
}
