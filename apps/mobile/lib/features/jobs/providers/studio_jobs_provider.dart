// Studio Jobs Provider - Manage posted jobs
// lib/features/jobs/providers/studio_jobs_provider.dart

import 'dart:async';
import 'dart:convert';

import 'package:convex_flutter/convex_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/hive_service.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/job.dart';
import '../../auth/providers/auth_provider.dart';

part 'studio_jobs_provider.g.dart';

class StudioInstructorSummary {
  const StudioInstructorSummary({
    required this.name,
    this.photoUrl,
    this.isVerified = false,
  });

  final String name;
  final String? photoUrl;
  final bool isVerified;

  factory StudioInstructorSummary.fromJson(Map<String, dynamic> json) {
    return StudioInstructorSummary(
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Instructor',
      photoUrl: (json['photoUrl'] as String?) ?? (json['avatarUrl'] as String?),
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }
}

class StudioJobRecord {
  const StudioJobRecord({
    required this.job,
    this.claimId,
    this.claimedInstructor,
  });

  final Job job;
  final String? claimId;
  final StudioInstructorSummary? claimedInstructor;

  bool get canRespondToClaim =>
      claimId != null &&
      (job.status == 'claimed' || job.status == 'backup_claimed');

  factory StudioJobRecord.fromJson(Map<String, dynamic> json) {
    final claimed = json['claimedInstructor'];
    return StudioJobRecord(
      job: Job.fromJson(json),
      claimId: json['claimId'] as String?,
      claimedInstructor: claimed is Map
          ? StudioInstructorSummary.fromJson(Map<String, dynamic>.from(claimed))
          : null,
    );
  }
}

/// State for studio jobs list.
class StudioJobsState {
  final List<StudioJobRecord> jobs;
  final bool isLoading;
  final String? error;

  const StudioJobsState({
    this.jobs = const [],
    this.isLoading = false,
    this.error,
  });

  StudioJobsState copyWith({
    List<StudioJobRecord>? jobs,
    bool? isLoading,
    String? error,
  }) {
    return StudioJobsState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<StudioJobRecord> get activeJobs => jobs
      .where((item) =>
          item.job.status == 'open' ||
          item.job.status == 'claimed' ||
          item.job.status == 'backup_claimed' ||
          item.job.status == 'confirmed')
      .toList();

  List<StudioJobRecord> get completedJobs => jobs
      .where((item) =>
          item.job.status == 'completed' ||
          item.job.status == 'cancelled' ||
          item.job.status == 'expired')
      .toList();
}

@riverpod
class StudioJobsNotifier extends _$StudioJobsNotifier {
  static const String _cacheKeyPrefix = 'studio_jobs';

  SubscriptionHandle? _subscription;
  String? _subscriptionSessionKey;
  StudioJobsState _lastState = const StudioJobsState();

  @override
  StudioJobsState build() {
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(userRoleProvider);

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });

    // Only subscribe if user is a studio.
    if (user != null && role == 'studio') {
      final sessionKey = '${user.uid}|$role';
      if (_subscription == null || _subscriptionSessionKey != sessionKey) {
        _subscription?.cancel();
        _subscription = null;
        _subscriptionSessionKey = sessionKey;

        final cached = _loadFromCache(user.uid);
        _lastState = cached.copyWith(
          isLoading: true,
          error: null,
        );
        Future.microtask(() => _subscribeToMyJobs(sessionKey, user.uid));
        return _lastState;
      }

      _lastState = _lastState.copyWith(
        // Keep the existing loading state; do not force spinner forever when
        // a studio legitimately has zero jobs.
        isLoading: _lastState.isLoading,
        error: null,
      );
      return _lastState;
    }

    _subscription?.cancel();
    _subscription = null;
    _subscriptionSessionKey = null;
    _lastState = const StudioJobsState();
    return _lastState;
  }

  String _cacheKeyForUser(String uid) => '$_cacheKeyPrefix:$uid';

  StudioJobsState _loadFromCache(String userUid) {
    try {
      final cached = HiveService().get(_cacheKeyForUser(userUid));
      if (cached is! List || cached.isEmpty) {
        return const StudioJobsState();
      }

      final parsed = cached
          .whereType<Map>()
          .map((entry) =>
              StudioJobRecord.fromJson(Map<String, dynamic>.from(entry)))
          .toList();

      parsed.sort((a, b) => b.job.createdAt.compareTo(a.job.createdAt));
      return StudioJobsState(jobs: parsed);
    } catch (e) {
      log.e('[StudioJobsNotifier] Failed to load cache: $e');
      return const StudioJobsState();
    }
  }

  Future<void> _subscribeToMyJobs(String sessionKey, String userUid) async {
    try {
      _subscription = await ConvexClient.instance.subscribe(
        name: 'jobs:getStudioJobs',
        args: const {},
        onUpdate: (data) => _handleJobsUpdate(data, sessionKey, userUid),
        onError: (message, value) {
          if (_subscriptionSessionKey != sessionKey) return;
          log.e('Studio jobs subscription error: $message');
          _setState(_lastState.copyWith(
            isLoading: false,
            error: message,
          ));
        },
      );
    } catch (e) {
      if (_subscriptionSessionKey != sessionKey) return;
      log.e('Failed to subscribe to studio jobs: $e');
      _setState(_lastState.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  List<Map<String, dynamic>> _decodeRowsFromPayload(dynamic payload) {
    if (payload == null) return const [];
    if (payload is String) {
      final normalized = payload.trim();
      if (normalized.isEmpty || normalized == 'null') return const [];
    }

    final dynamic parsed = payload is String ? json.decode(payload) : payload;
    if (parsed is! List) return const [];
    return parsed
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  void _handleJobsUpdate(String data, String sessionKey, String userUid) {
    if (_subscriptionSessionKey != sessionKey) return;

    try {
      final rows = _decodeRowsFromPayload(data);
      if (rows.isEmpty) {
        _setState(_lastState.copyWith(
          jobs: const [],
          isLoading: false,
          error: null,
        ));
        unawaited(
          HiveService()
              .save(_cacheKeyForUser(userUid), const <Map<String, dynamic>>[]),
        );
        return;
      }

      final jobsList = rows.map(StudioJobRecord.fromJson).toList();

      // Most recent jobs first.
      jobsList.sort((a, b) => b.job.createdAt.compareTo(a.job.createdAt));

      unawaited(HiveService().save(_cacheKeyForUser(userUid), rows));
      _setState(_lastState.copyWith(
        jobs: jobsList,
        isLoading: false,
        error: null,
      ));
    } catch (e) {
      log.e('Error parsing studio jobs: $e');
      _setState(_lastState.copyWith(
        isLoading: false,
        error: 'Failed to parse jobs data',
      ));
    }
  }

  Future<void> refresh() async {
    final user = ref.read(currentUserProvider);
    final role = ref.read(userRoleProvider);
    if (user == null || role != 'studio') return;

    final sessionKey = '${user.uid}|$role';
    _subscription?.cancel();
    _subscription = null;
    _subscriptionSessionKey = sessionKey;
    _setState(_lastState.copyWith(isLoading: true, error: null));

    try {
      final payload =
          await ConvexClient.instance.query('jobs:getStudioJobs', {});
      if (_subscriptionSessionKey == sessionKey) {
        final rows = _decodeRowsFromPayload(payload);
        final jobsList = rows.map(StudioJobRecord.fromJson).toList()
          ..sort((a, b) => b.job.createdAt.compareTo(a.job.createdAt));
        unawaited(HiveService().save(_cacheKeyForUser(user.uid), rows));
        _setState(_lastState.copyWith(
          jobs: jobsList,
          isLoading: false,
          error: null,
        ));
      }
    } catch (e) {
      if (_subscriptionSessionKey == sessionKey) {
        log.e('Studio jobs refresh query failed: $e');
        _setState(_lastState.copyWith(
          isLoading: false,
          error: e.toString(),
        ));
      }
    }

    await _subscribeToMyJobs(sessionKey, user.uid);
  }

  /// Post a new job.
  /// Throws with a user-readable error message on failure.
  Future<String> postJob({
    required String title,
    required String category,
    required DateTime startTime,
    required DateTime endTime,
    required double baseRate,
    required String address,
    required double latitude,
    required double longitude,
    String? description,
    bool requiresVerification = false,
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

      final jobId = result.toString().replaceAll('"', '').trim();

      if (jobId.isEmpty) {
        throw StateError('jobs:postJob returned empty job id');
      }

      _setState(_lastState.copyWith(error: null));
      return jobId;
    } catch (e) {
      log.e('Failed to post job: $e');
      final message = e.toString().replaceFirst('Exception: ', '');
      _setState(_lastState.copyWith(error: message));
      throw Exception(message);
    }
  }

  /// Cancel a job.
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

  /// Mark a confirmed job as completed.
  Future<bool> completeJob(String jobId) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'jobs:completeJob',
        args: {'jobId': jobId},
      );
      return true;
    } catch (e) {
      log.e('Failed to complete job: $e');
      return false;
    }
  }

  void _setState(StudioJobsState next) {
    _lastState = next;
    if (ref.mounted) {
      state = next;
    }
  }
}
