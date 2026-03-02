import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Studio jobs provider contract', () {
    test('shared jobs:getMyJobs is the primary studio my-jobs query', () {
      final source = File('lib/features/jobs/providers/studio_jobs_provider.dart')
          .readAsStringSync();

      expect(source, contains("String _activeQueryName = _myJobsQueryName;"));
      expect(
        source,
        contains(
          'for (final queryName in [_myJobsQueryName, _studioJobsQueryName])',
        ),
      );
    });

    test('legacy fallback activates for missing-function or timeout errors', () {
      final source = File('lib/features/jobs/providers/studio_jobs_provider.dart')
          .readAsStringSync();

      expect(source, contains('_shouldFallbackToLegacyStudioQuery'));
      expect(source, contains("message.contains('Could not find function')"));
      expect(source, contains("message.contains('Query timeout')"));
      expect(source, contains('error is TimeoutException'));
    });

    test('bootstrap failures terminate loading deterministically', () {
      final source = File('lib/features/jobs/providers/studio_jobs_provider.dart')
          .readAsStringSync();

      expect(source, contains('Unable to load studio jobs. Pull to refresh.'));
      expect(source, contains('isLoading: false,'));
    });

    test('post-job requires a valid convex id shape', () {
      final source = File('lib/features/jobs/providers/studio_jobs_provider.dart')
          .readAsStringSync();

      expect(source, contains('_looksLikeConvexId(jobId)'));
      expect(source, contains("RegExp(r'^[A-Za-z0-9_-]+\$')"));
    });

    test('post-job surfaces server validation errors before id parsing', () {
      final source = File('lib/features/jobs/providers/studio_jobs_provider.dart')
          .readAsStringSync();

      expect(source, contains('final serverError = _extractServerError(rawResult);'));
      expect(source, contains("normalized.contains('ArgumentValidationError')"));
      expect(source, contains("throw StateError(serverError);"));
    });
  });

  group('Studio post-job pricing contract', () {
    test('studio default base rate is applied until user edits rate', () {
      final source = File('lib/features/jobs/presentation/post_job_screen.dart')
          .readAsStringSync();

      expect(source, contains('bool _hasUserEditedRate = false;'));
      expect(source, contains('if (!_hasUserEditedRate && defaultRate != null)'));
      expect(source, contains('_hasUserEditedRate = true;'));
      expect(source, contains('_parseRateInput(_rateController.text)'));
      expect(source, contains("replaceAll(RegExp(r'[^0-9,.\\-]'), '')"));
    });
  });

  group('Studio jobs screen contract', () {
    test('auth loading state is guarded before auth-required panel', () {
      final source = File(
        'lib/features/studio/presentation/screens/studio_jobs_screen.dart',
      ).readAsStringSync();

      expect(source, contains('required this.isAuthLoading,'));
      expect(source, contains('if (isAuthLoading) {'));
    });
  });
}
