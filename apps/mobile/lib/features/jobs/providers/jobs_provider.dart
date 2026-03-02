/// Jobs Provider - Convex real-time subscriptions.
library;

import 'dart:convert';
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:convex_flutter/convex_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/offline_queue_manager.dart';
import '../../../core/services/hive_service.dart';
import '../../../data/models/job.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/logger.dart';

// Re-export Job for backward compatibility.
export '../../../data/models/job.dart';

part 'jobs_provider.g.dart';

// Track pending operations per job
class PendingOperation {
  final String mutationId;
  final String operation; // 'claimJob' | 'withdrawClaim'
  final String status; // 'pending' | 'syncing' | 'completed' | 'failed'

  const PendingOperation({
    required this.mutationId,
    required this.operation,
    required this.status,
  });
}

// Jobs list state
class JobsState {
  final List<Job> jobs;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;
  final Map<String, PendingOperation> pendingOperations; // jobId -> operation

  const JobsState({
    this.jobs = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
    this.pendingOperations = const {},
  });

  JobsState copyWith({
    List<Job>? jobs,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
    Map<String, PendingOperation>? pendingOperations,
  }) {
    return JobsState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      pendingOperations: pendingOperations ?? this.pendingOperations,
    );
  }

  List<Job> get sosJobs => jobs.where((j) => j.isSos).toList();
  List<Job> get regularJobs => jobs.where((j) => !j.isSos).toList();

  // Check if a job has a pending operation
  bool isJobPending(String jobId) => pendingOperations.containsKey(jobId);

  // Get pending operation for a job
  PendingOperation? getPendingOperation(String jobId) =>
      pendingOperations[jobId];
}

@Riverpod(keepAlive: true)
class JobsNotifier extends _$JobsNotifier {
  SubscriptionHandle? _subscription;
  bool _bootstrapped = false;
  JobsState _lastState = const JobsState();

  @override
  JobsState build() {
    final userId = ref.watch(currentUserProvider)?.uid;
    final hasCompletedOnboarding = ref.watch(hasCompletedOnboardingProvider);

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
      final queue = OfflineQueueManager();
      queue.onMutationStatusChange = null;
      queue.onShowNotification = null;
    });

    // Setup offline queue callbacks
    _setupOfflineQueueCallbacks();

    if (userId != null && hasCompletedOnboarding) {
      if (!_bootstrapped) {
        _bootstrapped = true;
        final cachedState = _loadFromCacheSnapshot();
        Future.microtask(() => _subscribeToJobs());
        _lastState = cachedState.copyWith(isLoading: true, error: null);
        return _lastState;
      }

      if (_subscription == null) {
        Future.microtask(() => _subscribeToJobs());
      }
      _lastState = _lastState.copyWith(
        isLoading: _lastState.jobs.isEmpty,
        error: null,
      );
      return _lastState;
    }

    if (_subscription != null) {
      _subscription?.cancel();
      _subscription = null;
    }
    _bootstrapped = false;
    _lastState = const JobsState(isLoading: false);
    return _lastState;
  }

  JobsState _loadFromCacheSnapshot() {
    try {
      final cached = HiveService().get('jobs_nearby');
      if (cached != null) {
        final jobsList = (cached as List)
            .map((j) => Job.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        return JobsState(
          jobs: jobsList,
          isLoading: false,
          lastUpdated: DateTime.now(),
        );
      }
    } catch (e) {
      log.e('[JobsNotifier] Cache load error: $e');
    }
    return const JobsState();
  }

  void _setupOfflineQueueCallbacks() {
    OfflineQueueManager().onMutationStatusChange = (mutationId, status) {
      if (!ref.mounted || !_bootstrapped) return;
      final entry = _lastState.pendingOperations.entries.firstWhere(
        (e) => e.value.mutationId == mutationId,
        orElse: () => MapEntry(
            '', PendingOperation(mutationId: '', operation: '', status: '')),
      );

      if (entry.key.isNotEmpty) {
        final updatedOps =
            Map<String, PendingOperation>.from(_lastState.pendingOperations);
        if (status == 'completed' || status == 'failed') {
          updatedOps.remove(entry.key);
        } else {
          updatedOps[entry.key] = PendingOperation(
            mutationId: mutationId,
            operation: entry.value.operation,
            status: status,
          );
        }
        _setState(_lastState.copyWith(pendingOperations: updatedOps));
      }
    };

    OfflineQueueManager().onShowNotification = (message) {
      if (!ref.mounted) return;
      log.i('[OfflineQueue] Notification: $message');
    };
  }

  Future<void> _subscribeToJobs() async {
    if (!ref.mounted) return;
    final auth = ref.read(authProvider);
    if (auth.user == null) return;

    _subscription = await ConvexClient.instance.subscribe(
      name: 'jobs:getNearbyJobs',
      args: {'limit': AppConstants.jobsPageSize.toString()},
      onUpdate: (data) => _handleJobsUpdate(data),
      onError: (message, value) {
        if (!ref.mounted) return;
        _setState(_lastState.copyWith(isLoading: false, error: message));
      },
    );
  }

  void _handleJobsUpdate(String data) {
    if (!ref.mounted) return;
    try {
      if (data == 'null' || data.isEmpty) {
        if (!ref.mounted) return;
        _setState(_lastState.copyWith(isLoading: false, jobs: []));
        return;
      }

      final dynamic parsed = json.decode(data);
      if (parsed == null || (parsed is List && parsed.isEmpty)) {
        if (!ref.mounted) return;
        _setState(_lastState.copyWith(isLoading: false, jobs: []));
        return;
      }
      final jobsList = (parsed as List)
          .map((j) => Job.fromJson(j as Map<String, dynamic>))
          .toList();

      // Save to cache
      HiveService().save('jobs_nearby', parsed);

      if (!ref.mounted) return;
      _setState(_lastState.copyWith(
        jobs: jobsList,
        isLoading: false,
        lastUpdated: DateTime.now(),
      ));
    } catch (e) {
      log.e('[JobsNotifier] Parse error: $e');
      if (!ref.mounted) return;
      _setState(
          _lastState.copyWith(isLoading: false, error: 'Failed to load jobs'));
    }
  }

  Future<void> refresh() async {
    _setState(_lastState.copyWith(isLoading: true, error: null));
    _subscription?.cancel();
    _subscription = null;
    await _subscribeToJobs();
  }

  Future<bool> claimJob(String jobId) async {
    try {
      final mutationId = await OfflineQueueManager().queueMutation(
        operation: 'claimJob',
        payload: {'jobId': jobId},
        optimisticUpdate: () => log.i('[JobsNotifier] Claiming job $jobId'),
      );

      final updatedOps =
          Map<String, PendingOperation>.from(_lastState.pendingOperations);
      updatedOps[jobId] = PendingOperation(
          mutationId: mutationId, operation: 'claimJob', status: 'pending');
      _setState(
          _lastState.copyWith(pendingOperations: updatedOps, error: null));
      return true;
    } catch (e) {
      _setState(_lastState.copyWith(error: e.toString()));
      return false;
    }
  }

  Future<bool> withdrawClaim(String jobId) async {
    try {
      final mutationId = await OfflineQueueManager().queueMutation(
        operation: 'withdrawClaim',
        payload: {'jobId': jobId},
        optimisticUpdate: () =>
            log.i('[JobsNotifier] Withdrawing claim for job $jobId'),
      );

      final updatedOps =
          Map<String, PendingOperation>.from(_lastState.pendingOperations);
      updatedOps[jobId] = PendingOperation(
          mutationId: mutationId,
          operation: 'withdrawClaim',
          status: 'pending');
      _setState(
          _lastState.copyWith(pendingOperations: updatedOps, error: null));
      return true;
    } catch (e) {
      _setState(_lastState.copyWith(error: e.toString()));
      return false;
    }
  }

  void _setState(JobsState next) {
    _lastState = next;
    if (ref.mounted) {
      state = next;
    }
  }
}

// Manual StreamProvider for real-time single job updates to bypass generator issues
final streamingJobProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, jobId) {
  final controller = StreamController<Map<String, dynamic>?>();
  SubscriptionHandle? handle;

  Future<void> start() async {
    try {
      handle = await ConvexClient.instance.subscribe(
        name: 'jobs:getJobById',
        args: {'jobId': jobId},
        onUpdate: (data) {
          final decoded = json.decode(data);
          if (!controller.isClosed) {
            controller.add(decoded as Map<String, dynamic>?);
          }
        },
        onError: (err, val) {
          if (!controller.isClosed) {
            controller.addError(err);
          }
        },
      );
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  start();

  ref.onDispose(() {
    handle?.cancel();
    controller.close();
  });

  return controller.stream;
});

@riverpod
Future<Job?> job(Ref ref, String jobId) async {
  final resultJson =
      await ConvexClient.instance.query('jobs:getJobById', {'jobId': jobId});
  final dynamic result = json.decode(resultJson);
  if (result == null) return null;
  return Job.fromJson(result as Map<String, dynamic>);
}
