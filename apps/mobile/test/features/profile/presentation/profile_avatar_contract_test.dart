import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Profile avatar contract', () {
    test('profile screen supports applying account photo', () {
      final source =
          File('lib/features/profile/presentation/profile_screen.dart')
              .readAsStringSync();

      expect(source, contains('_applyAccountPhoto'));
      expect(source, contains('profileUseAccountPhoto'));
      expect(source, contains('avatarUrl: photo'));
    });

    test('auth profile update pipeline forwards avatarUrl to backend', () {
      final providerSource =
          File('lib/features/auth/providers/auth_provider.dart')
              .readAsStringSync();
      final serviceSource = File('lib/features/auth/services/user_service.dart')
          .readAsStringSync();

      expect(providerSource, contains('String? avatarUrl'));
      expect(providerSource, contains('avatarUrl: avatarUrl'));
      expect(serviceSource, contains("if (avatarUrl != null) 'avatarUrl': avatarUrl"));
    });
  });
}
