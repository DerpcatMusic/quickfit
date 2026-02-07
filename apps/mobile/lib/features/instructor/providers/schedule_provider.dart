import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:convex_flutter/convex_flutter.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/utils/logger.dart';

part 'schedule_provider.g.dart';

class ScheduleState {
  final List<Map<String, dynamic>> jobs;
  final bool isLoading;
  final String? error;

  const ScheduleState({
    this.jobs = const [],
    this.isLoading = false,
    this.error,
  });

  ScheduleState copyWith({
    List<Map<String, dynamic>>? jobs,
    bool? isLoading,
    String? error,
  }) {
    return ScheduleState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

@Riverpod(keepAlive: true)
class ScheduleNotifier extends _$ScheduleNotifier {
  SubscriptionHandle? _subscription;

  @override
  ScheduleState build() {
    ref.onDispose(() {
      _subscription?.cancel();
    });

    if (_subscription == null) {
      _loadFromCache();
      Future.microtask(() => _subscribe());
      return state.copyWith(isLoading: true);
    }

    return state;
  }

  void _loadFromCache() {
    try {
      final cached = HiveService().get('instructor_schedule');
      if (cached != null) {
        final List<Map<String, dynamic>> jobs = (cached as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        state = state.copyWith(jobs: jobs);
      }
    } catch (e) {
      log.e('[ScheduleNotifier] Cache load error: $e');
    }
  }

  Future<void> _subscribe() async {
    try {
      _subscription = await ConvexClient.instance.subscribe(
        name: 'jobs:getInstructorSchedule',
        args: {},
        onUpdate: (data) => _handleUpdate(data),
        onError: (err, _) {
          state = state.copyWith(isLoading: false, error: err);
        },
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _handleUpdate(String data) {
    try {
      if (data == 'null' || data.isEmpty) {
        state = state.copyWith(isLoading: false, jobs: []);
        return;
      }

      final dynamic parsed = json.decode(data);
      if (parsed == null || (parsed is List && parsed.isEmpty)) {
        state = state.copyWith(isLoading: false, jobs: []);
        return;
      }

      final jobs = (parsed as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Cache
      HiveService().save('instructor_schedule', jobs);

      state = state.copyWith(jobs: jobs, isLoading: false);
    } catch (e) {
      log.e('[ScheduleNotifier] Parse error: $e');
      state =
          state.copyWith(isLoading: false, error: 'Failed to update schedule');
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    _subscription?.cancel();
    await _subscribe();
  }
}
