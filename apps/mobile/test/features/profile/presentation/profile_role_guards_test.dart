import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Profile role guards', () {
    test('radius controls are instructor-only in profile edit and save path', () {
      final source = File('lib/features/profile/presentation/profile_screen.dart')
          .readAsStringSync();

      expect(source, contains("if (isInstructor) ...["));
      expect(
        source,
        contains("radiusKm: authState.role == 'instructor' ? _radiusKm : null"),
      );
      expect(
        source,
        contains("if (ref.read(authProvider).role != 'instructor') return;"),
      );
    });
  });
}
