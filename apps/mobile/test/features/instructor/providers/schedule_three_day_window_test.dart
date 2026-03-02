import 'package:flutter_test/flutter_test.dart';
import 'package:quickfit/features/instructor/models/schedule_event.dart';
import 'package:quickfit/features/instructor/providers/schedule_provider.dart';

List<DateTime> _threeDayWindow(DateTime selected) {
  return [
    selected.subtract(const Duration(days: 1)),
    selected,
    selected.add(const Duration(days: 1)),
  ];
}

List<String> _eventIdsForWindow(ScheduleState state, DateTime selected) {
  final ids = <String>[];
  for (final day in _threeDayWindow(selected)) {
    ids.addAll(state.eventsForDay(day).map((event) => event.jobId));
  }
  return ids;
}

ScheduleEvent _event({
  required String jobId,
  required DateTime day,
  required int startHour,
}) {
  final start = DateTime(day.year, day.month, day.day, startHour);
  return ScheduleEvent(
    claimId: 'claim_$jobId',
    jobId: jobId,
    title: 'Class $jobId',
    studioName: 'Studio',
    startTime: start,
    endTime: start.add(const Duration(hours: 1)),
    claimStatus: 'accepted',
    jobStatus: 'open',
    address: '',
    currentRate: 200,
  );
}

void main() {
  test('three-day window content shifts by one day when selected day shifts',
      () {
    final selected = DateTime(2026, 2, 10);
    final state = ScheduleState(
      events: [
        _event(jobId: 'job_9', day: DateTime(2026, 2, 9), startHour: 9),
        _event(jobId: 'job_10', day: DateTime(2026, 2, 10), startHour: 10),
        _event(jobId: 'job_11', day: DateTime(2026, 2, 11), startHour: 11),
        _event(jobId: 'job_12', day: DateTime(2026, 2, 12), startHour: 12),
      ],
    );

    expect(
      _eventIdsForWindow(state, selected),
      equals(['job_9', 'job_10', 'job_11']),
    );
    expect(
      _eventIdsForWindow(state, selected.add(const Duration(days: 1))),
      equals(['job_10', 'job_11', 'job_12']),
    );
  });

  test('forward then backward day shift returns to original three-day window',
      () {
    final selected = DateTime(2026, 5, 14);

    final shiftedForward = selected.add(const Duration(days: 1));
    final shiftedBack = shiftedForward.subtract(const Duration(days: 1));

    expect(_threeDayWindow(shiftedBack), equals(_threeDayWindow(selected)));
  });

  test('eventsForDay remains time-sorted within each day after shifts', () {
    final day = DateTime(2026, 3, 1);
    final state = ScheduleState(
      events: [
        _event(jobId: 'late', day: day, startHour: 15),
        _event(jobId: 'early', day: day, startHour: 8),
        _event(jobId: 'mid', day: day, startHour: 12),
      ],
    );

    final sortedIds = state.eventsForDay(day).map((event) => event.jobId);
    expect(sortedIds, equals(['early', 'mid', 'late']));
  });
}
