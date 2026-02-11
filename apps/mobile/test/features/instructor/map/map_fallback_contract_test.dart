import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Instructor map fallback contract', () {
    test('radius mode has jobs:getJobsForMap fallback when geo subscription fails', () {
      final source = File(
        'lib/features/instructor/map/presentation/instructor_map_screen.dart',
      ).readAsStringSync();

      expect(source, contains('_loadRadiusMapJobsFallback'));
      expect(source, contains("query('jobs:getJobsForMap', {})"));
      expect(source, contains('if (_mode == SelectionMode.radius)'));
    });

    test('marker label formatting avoids mojibake separator', () {
      final source = File(
        'lib/features/instructor/map/presentation/instructor_map_screen.dart',
      ).readAsStringSync();

      expect(source.contains('â€¢'), isFalse);
      expect(source, contains(r"$countLabel - $postedLabel"));
    });
  });
}
