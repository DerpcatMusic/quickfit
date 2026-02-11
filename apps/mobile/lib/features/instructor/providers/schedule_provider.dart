import 'dart:convert';

import 'package:convex_flutter/convex_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/hive_service.dart';
import '../../../core/utils/logger.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/schedule_event.dart';

part 'schedule_provider.g.dart';

class ScheduleState {
  const ScheduleState({
    this.events = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  static const _noChange = Object();

  final List<ScheduleEvent> events;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  ScheduleState copyWith({
    List<ScheduleEvent>? events,
    bool? isLoading,
    Object? error = _noChange,
    DateTime? lastUpdated,
  }) {
    return ScheduleState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _noChange) ? this.error : error as String?,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  List<ScheduleEvent> eventsForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    return events.where((event) => _isSameDay(event.day, dayStart)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  double bookedHoursForDay(DateTime day) {
    return eventsForDay(day)
        .where((event) => event.countsTowardBookedHours)
        .fold<double>(0, (sum, event) => sum + event.durationHours);
  }

  double bookedHoursForWeek(DateTime anchorDate) {
    final anchor = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    final weekStart = anchor.subtract(Duration(days: anchor.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    return events
        .where((event) =>
            !event.day.isBefore(weekStart) && event.day.isBefore(weekEnd))
        .where((event) => event.countsTowardBookedHours)
        .fold<double>(0, (sum, event) => sum + event.durationHours);
  }

  double bookedHoursForMonth(DateTime month) {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    return events
        .where((event) =>
            !event.day.isBefore(monthStart) && event.day.isBefore(monthEnd))
        .where((event) => event.countsTowardBookedHours)
        .fold<double>(0, (sum, event) => sum + event.durationHours);
  }

  int jobsCountForDay(DateTime day) => eventsForDay(day).length;

  List<ScheduleEvent> get upcomingEvents {
    final now = DateTime.now();
    return events.where((event) => event.endTime.isAfter(now)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

@Riverpod(keepAlive: true)
class ScheduleNotifier extends _$ScheduleNotifier {
  static const _cacheKey = 'instructor_schedule_v2';
  SubscriptionHandle? _subscription;
  bool _bootstrapped = false;
  bool _isSubscribing = false;

  @override
  ScheduleState build() {
    final userId = ref.watch(currentUserProvider)?.uid;
    final role = ref.watch(userRoleProvider);

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
      _isSubscribing = false;
    });

    if (userId != null && role == 'instructor') {
      if (!_bootstrapped) {
        _bootstrapped = true;
        final cachedState = _loadFromCacheSnapshot();
        Future.microtask(() => _subscribe());
        return cachedState.copyWith(isLoading: true, error: null);
      }

      if (_subscription == null && !_isSubscribing) {
        Future.microtask(() => _subscribe());
      }
      return state;
    }

    if (_subscription != null) {
      _subscription?.cancel();
      _subscription = null;
    }
    _bootstrapped = false;
    return const ScheduleState();
  }

  ScheduleState _loadFromCacheSnapshot() {
    try {
      final cached = HiveService().get(_cacheKey);
      if (cached is! Map) return const ScheduleState();

      final eventsRaw = cached['events'];
      final savedAtMs = cached['savedAt'] as int?;
      if (eventsRaw is! List) return const ScheduleState();

      final events = eventsRaw
          .whereType<Map>()
          .map((raw) =>
              ScheduleEvent.fromCacheJson(Map<String, dynamic>.from(raw)))
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      return ScheduleState(
        events: events,
        lastUpdated: savedAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(savedAtMs)
            : null,
      );
    } catch (e) {
      log.e('[ScheduleNotifier] Cache load error: $e');
      return const ScheduleState();
    }
  }

  Future<void> _subscribe() async {
    if (!ref.mounted || _isSubscribing) return;
    _isSubscribing = true;
    try {
      _subscription?.cancel();
      _subscription = null;
      _subscription = await ConvexClient.instance.subscribe(
        name: 'claims:getMyClaims',
        args: const {},
        onUpdate: _handleUpdate,
        onError: (err, _) {
          if (!ref.mounted) return;
          state = state.copyWith(isLoading: false, error: err);
        },
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    } finally {
      _isSubscribing = false;
    }
  }

  void _handleUpdate(String data) {
    if (!ref.mounted) return;
    try {
      if (data.isEmpty || data == 'null') {
        state = state.copyWith(
          events: const [],
          isLoading: false,
          error: null,
          lastUpdated: DateTime.now(),
        );
        return;
      }

      final parsed = json.decode(data);
      if (parsed is! List) {
        state = state.copyWith(
          events: const [],
          isLoading: false,
          error: null,
          lastUpdated: DateTime.now(),
        );
        return;
      }

      final events = <ScheduleEvent>[];
      for (final rawClaim in parsed) {
        if (rawClaim is! Map) continue;
        try {
          final claim = Map<String, dynamic>.from(rawClaim);
          final claimStatus = claim['status']?.toString() ?? '';
          if (claimStatus != 'accepted' && claimStatus != 'pending') {
            continue;
          }

          final event = ScheduleEvent.fromClaimJson(claim);
          if (event.isCancelledLike) continue;
          events.add(event);
        } catch (e) {
          log.w('[ScheduleNotifier] Skipping malformed schedule claim: $e');
        }
      }

      events.sort((a, b) => a.startTime.compareTo(b.startTime));

      HiveService().save(_cacheKey, {
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'events': events.map((event) => event.toCacheJson()).toList(),
      });

      if (!ref.mounted) return;
      state = state.copyWith(
        events: events,
        isLoading: false,
        error: null,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      log.e('[ScheduleNotifier] Parse error: $e');
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update schedule',
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    _subscription?.cancel();
    _subscription = null;
    _isSubscribing = false;
    await _subscribe();
  }
}
