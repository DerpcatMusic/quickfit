import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Studio localization regressions', () {
    test('studio jobs screen no longer has hardcoded studio UX copy', () {
      final source = File(
              'lib/features/studio/presentation/screens/studio_jobs_screen.dart')
          .readAsStringSync();

      const forbidden = <String>[
        "Studio session required",
        "Go to login",
        "No jobs yet in this section.",
        "Mark class completed?",
        "Mark completed",
        "Job marked as completed.",
        "Failed to complete job.",
      ];

      for (final value in forbidden) {
        expect(source.contains(value), isFalse,
            reason: 'Found hardcoded: $value');
      }
    });

    test('studio public profile screen no longer has hardcoded copy', () {
      final source = File(
              'lib/features/studio/presentation/screens/studio_public_profile_screen.dart')
          .readAsStringSync();

      const forbidden = <String>[
        "Studio Profile",
        "Studio not found",
        "Open jobs:",
        "Active jobs:",
        "Available Jobs",
        "No available jobs right now.",
      ];

      for (final value in forbidden) {
        expect(source.contains(value), isFalse,
            reason: 'Found hardcoded: $value');
      }
    });

    test('post job uses sticky bottom submit CTA', () {
      final source = File('lib/features/jobs/presentation/post_job_screen.dart')
          .readAsStringSync();

      expect(source, contains('bottomNavigationBar: SafeArea('));
      expect(
          source,
          contains(
              'text: l10n.postJobButtonWithRate(_displayRate.toString())'));
    });

    test('studio billing sheet no longer hardcodes billing copy', () {
      final source = File(
        'lib/features/studio/billing/presentation/studio_billing_sheet.dart',
      ).readAsStringSync();

      const forbidden = <String>[
        'Billing & Invoicing',
        'No provider connected yet.',
        'Connect Morning',
        'Connect iCount',
        'Base URL is required',
        'Set active',
        'Set inactive',
      ];

      for (final value in forbidden) {
        expect(source.contains(value), isFalse,
            reason: 'Found hardcoded: $value');
      }
    });
  });
}
