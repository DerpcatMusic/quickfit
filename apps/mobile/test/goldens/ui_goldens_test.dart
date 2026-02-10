import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfit/core/theme/app_colors.dart';
import 'package:quickfit/data/models/job.dart';
import 'package:quickfit/features/instructor/map/presentation/widgets/instructor_stats_card.dart';
import 'package:quickfit/shared/widgets/job_card.dart';
import 'package:quickfit/shared/widgets/sos_badge.dart';

Future<void> _pumpGolden(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(360, 640),
}) async {
  await tester.binding.setSurfaceSize(size);
  final colors = AppColors.light;
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.cobaltAccent,
      brightness: Brightness.light,
    ),
    extensions: const [AppColors.light],
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: const Key('golden'),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Job _sampleJob() {
  return Job(
    id: 'job_1',
    studioId: 'studio_1',
    studioName: 'Studio One',
    title: 'Pilates Class',
    category: 'pilates',
    startTime: DateTime(2026, 2, 9, 18, 0),
    endTime: DateTime(2026, 2, 9, 19, 0),
    baseRate: 180,
    currentRate: 200,
    latitude: 32.0853,
    longitude: 34.7818,
    address: 'Tel Aviv',
    status: 'open',
    isSos: false,
    distanceKm: 2.5,
    createdAt: DateTime(2026, 2, 9, 9, 0),
    notes: 'Bring a mat',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('InstructorStatsCard golden', (tester) async {
    await _pumpGolden(
      tester,
      const Padding(
        padding: EdgeInsets.all(16),
        child: InstructorStatsCard(
          totalJobs: 42,
          earnings: 12450,
          visibleJobsCount: 7,
        ),
      ),
      size: const Size(360, 160),
    );

    await expectLater(
      find.byKey(const Key('golden')),
      matchesGoldenFile('goldens/instructor_stats_card.png'),
    );
  });

  testWidgets('JobCardCompact golden', (tester) async {
    await _pumpGolden(
      tester,
      Padding(
        padding: const EdgeInsets.all(16),
        child: JobCardCompact(job: _sampleJob()),
      ),
      size: const Size(360, 140),
    );

    await expectLater(
      find.byKey(const Key('golden')),
      matchesGoldenFile('goldens/job_card_compact.png'),
    );
  });

  testWidgets('Badges golden', (tester) async {
    await _pumpGolden(
      tester,
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          const SosBadge(animate: false),
          TimeRemainingBadge(timeRemaining: const Duration(minutes: 45)),
          TimeRemainingBadge(timeRemaining: const Duration(hours: 2, minutes: 10)),
          TimeRemainingBadge(timeRemaining: const Duration(hours: 5)),
          TimeRemainingBadge(timeRemaining: const Duration(minutes: -5)),
          const BoostedRateBadge(originalRate: 180, boostedRate: 210),
        ],
      ),
      size: const Size(360, 200),
    );

    await expectLater(
      find.byKey(const Key('golden')),
      matchesGoldenFile('goldens/badges.png'),
    );
  });
}
