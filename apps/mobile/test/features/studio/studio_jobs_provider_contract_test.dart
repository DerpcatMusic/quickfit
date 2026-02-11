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

    test('legacy fallback is only for missing-function compatibility', () {
      final source = File('lib/features/jobs/providers/studio_jobs_provider.dart')
          .readAsStringSync();

      expect(source, contains("queryName == _myJobsQueryName &&"));
      expect(source, contains("contains('Could not find function')"));
      expect(
        source,
        contains(
          "!e.toString().contains('Could not find function')",
        ),
      );
    });
  });
}
