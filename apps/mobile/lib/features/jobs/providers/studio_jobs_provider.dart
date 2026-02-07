// Studio Jobs Provider - Manage posted jobs
// lib/features/jobs/providers/studio_jobs_provider.dart

import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:convex_flutter/convex_flutter.dart';

import '../../../core/utils/logger.dart';
import '../../../data/models/job.dart';
import '../../auth/providers/auth_provider.dart';

part 'studio_jobs_provider.g.dart';

/// State for studio jobs list
class StudioJobsState {
  final List<Job> jobs;
  final bool isLoading;
  final String? error;

  const StudioJobsState({
    this.jobs = const [],
    this.isLoading = false,
    this.error,
  });

  StudioJobsState copyWith({
    List<Job>? jobs,
    bool? isLoading,
    String? error,
  }) {
    return StudioJobsState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  // Helper getters
  List<Job> get activeJobs =>
      jobs.where((j) => j.status == 'open' || j.status == 'claimed').toList();

  List<Job> get completedJobs => jobs
      .where((j) => j.status == 'completed' || j.status == 'cancelled')
      .toList();
}

@riverpod
class StudioJobsNotifier extends _$StudioJobsNotifier {
  SubscriptionHandle? _subscription;

  @override
  StudioJobsState build() {
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(userRoleProvider);

    // Only subscribe if user is a studio
    if (user != null && role == 'studio') {
      if (_subscription == null) {
        Future.microtask(() => _subscribeToMyJobs());
        return const StudioJobsState(isLoading: true);
      }
      return state;
    }

    // Cleanup if role changes or logout
    if (_subscription != null) {
      _subscription?.cancel();
      _subscription = null;
    }

    return const StudioJobsState(isLoading: false);
  }

  Future<void> _subscribeToMyJobs() async {
    try {
      _subscription = await ConvexClient.instance.subscribe(
        name: 'jobs:getStudioJobs',
        args: {},
        onUpdate: (data) {
          _handleJobsUpdate(data);
        },
        onError: (message, value) {
          log.e('Studio jobs subscription error: $message');
          state = state.copyWith(
            isLoading: false,
            error: message,
          );
        },
      );
    } catch (e) {
      log.e('Failed to subscribe to studio jobs: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void _handleJobsUpdate(String data) {
    try {
      final dynamic parsed = json.decode(data);
      if (parsed == null) {
        state = state.copyWith(isLoading: false, jobs: []);
        return;
      }

      final jobsList = (parsed as List)
          .map((j) => Job.fromJson(j as Map<String, dynamic>))
          .toList();

      // Sort by date descending
      jobsList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(
        jobs: jobsList,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      log.e('Error parsing studio jobs: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to parse jobs data',
      );
    }
  }

  /// Post a new job
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

      // Result is the jobId
      return result.replaceAll('"', '');
    } catch (e) {
      log.e('Failed to post job: $e');
      // Show error but don't clear state (keep existing jobs)
      return null;
    }
  }

  /// Cancel a job
  Future<bool> cancelJob(String jobId) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'jobs:cancelJob',
        args: {'jobId': jobId},
      );
      return true;
    } catch (e) {
      log.e('Failed to cancel job: $e');
      return false;
    }
  }
}
