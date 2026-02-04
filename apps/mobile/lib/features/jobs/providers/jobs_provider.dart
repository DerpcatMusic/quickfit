/// Jobs Provider - Convex real-time subscriptions.
library;

import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:convex_flutter/convex_flutter.dart';

import '../../../core/services/location_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/job.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/logger.dart';

// Re-export Job for backward compatibility.
export '../../../data/models/job.dart';

part 'jobs_provider.g.dart';

// Jobs list state
class JobsState {
  final List<Job> jobs;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  const JobsState({
    this.jobs = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  JobsState copyWith({
    List<Job>? jobs,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return JobsState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  List<Job> get sosJobs => jobs.where((j) => j.isSos).toList();
  List<Job> get regularJobs => jobs.where((j) => !j.isSos).toList();
}

@riverpod
class JobsNotifier extends _$JobsNotifier {
  SubscriptionHandle? _subscription;

  @override
  JobsState build() {
    final userId = ref.watch(currentUserProvider)?.uid;
    final hasCompletedOnboarding = ref.watch(hasCompletedOnboardingProvider);

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });

    if (userId != null && hasCompletedOnboarding) {
      // Logic safety: don't subscribe if we already have a handle.
      if (_subscription == null) {
        Future.microtask(() => _subscribeToJobs());
        return const JobsState(isLoading: true);
      }
      // If we already have a subscription, keep the current state to prevent "bouncing" UI.
      return state;
    }

    // Reset subscription if user logs out or onboarding is revoked
    if (_subscription != null) {
      _subscription?.cancel();
      _subscription = null;
    }
    return const JobsState(isLoading: false);
  }

  Future<void> _subscribeToJobs() async {
    final auth = ref.read(authProvider);
    if (auth.user == null) return;

    final lat = LocationService.instance.latitude;
    final lng = LocationService.instance.longitude;

    if (lat == null || lng == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'Location not available',
      );
      return;
    }

    log.i('Subscribing to jobs at $lat, $lng');
    _subscription = await ConvexClient.instance.subscribe(
      name: 'jobs:getNearbyJobs',
      args: {
        'limit': AppConstants.jobsPageSize.toString(),
      },
      onUpdate: (data) {
        log.i('Jobs update received: ${data.length} bytes');
        _handleJobsUpdate(data);
      },
      onError: (message, value) {
        log.e('Jobs subscription error: $message');
        state = state.copyWith(
          isLoading: false,
          error: message,
        );
      },
    );
  }

  void _handleJobsUpdate(String data) {
    try {
      final dynamic parsed = json.decode(data);
      log.i('Parsed jobs: ${parsed is List ? parsed.length : 0} items');

      if (parsed == null || (parsed is List && parsed.isEmpty)) {
        state = state.copyWith(isLoading: false, jobs: []);
        return;
      }

      final jobsList = (parsed as List)
          .map((j) => Job.fromJson(j as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        jobs: jobsList,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      log.e('Error parsing jobs: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    _subscription?.cancel();
    await _subscribeToJobs();
  }

  Future<bool> claimJob(String jobId) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'jobs:claimJob',
        args: {'jobId': jobId},
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> withdrawClaim(String jobId) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'jobs:withdrawClaim',
        args: {'jobId': jobId},
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

// Provider for studio's posted jobs
@riverpod
class StudioJobsNotifier extends _$StudioJobsNotifier {
  SubscriptionHandle? _subscription;

  @override
  JobsState build() {
    final userId = ref.watch(currentUserProvider)?.uid;
    final role = ref.watch(userRoleProvider);

    ref.onDispose(() {
      _subscription?.cancel();
    });

    // Only subscribe for studios.
    if (userId != null && role == 'studio') {
      if (_subscription == null) {
        Future.microtask(() => _subscribeToStudioJobs());
        return const JobsState(isLoading: true);
      }
      return state;
    }

    return const JobsState(isLoading: false);
  }

  Future<void> _subscribeToStudioJobs() async {
    final auth = ref.read(authProvider);
    if (auth.user == null) return;

    _subscription = await ConvexClient.instance.subscribe(
      name: 'jobs:getStudioJobs',
      args: {},
      onUpdate: (data) {
        _handleStudioJobsUpdate(data);
      },
      onError: (message, value) {
        state = state.copyWith(
          isLoading: false,
          error: message,
        );
      },
    );
  }

  void _handleStudioJobsUpdate(String data) {
    try {
      final dynamic parsed = json.decode(data);

      if (parsed == null) {
        state = state.copyWith(isLoading: false, jobs: []);
        return;
      }

      final jobsList = (parsed as List)
          .map((j) => Job.fromJson(j as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        jobs: jobsList,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<String?> postJob({
    required String title,
    required String category,
    required DateTime startTime,
    required DateTime endTime,
    required double baseRate,
    required String address,
    required double latitude,
    required double longitude,
    String? description,
    bool requiresVerification = true,
  }) async {
    try {
      final result = await ConvexClient.instance.mutation(
        name: 'jobs:postJob',
        args: {
          'title': title,
          'category': category,
          'startTime': startTime.millisecondsSinceEpoch,
          'endTime': endTime.millisecondsSinceEpoch,
          'baseRate': baseRate,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
          'requiresVerification': requiresVerification,
          if (description != null) 'description': description,
        },
      );
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> cancelJob(String jobId) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'jobs:cancelJob',
        args: {'jobId': jobId},
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

// Provider for a single job - using positional args
@riverpod
Future<Job?> job(Ref ref, String jobId) async {
  final resultJson = await ConvexClient.instance.query(
    'jobs:getJob',
    {'jobId': jobId},
  );

  final result = json.decode(resultJson);
  if (result == null) return null;
  return Job.fromJson(result as Map<String, dynamic>);
}
