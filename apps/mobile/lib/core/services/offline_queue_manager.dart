import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/pending_mutation.dart';
import 'hive_service.dart';
import 'convex_service.dart';
import '../utils/logger.dart';

class OfflineQueueManager {
  static final OfflineQueueManager _instance = OfflineQueueManager._internal();
  factory OfflineQueueManager() => _instance;
  OfflineQueueManager._internal();

  final _connectivity = Connectivity();
  final _uuid = const Uuid();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;
  bool _isOnline = true;

  Function(String mutationId, String status)? onMutationStatusChange;
  Function(String message)? onShowNotification;

  void initialize() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
      final wasOffline = !_isOnline;
      _isOnline = result != ConnectivityResult.none;

      if (wasOffline && _isOnline) {
        log.i('[OfflineQueue] Back online! Triggering sync...');
        _triggerSync();
      }
    });

    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    _isOnline = result != ConnectivityResult.none;
  }

  Future<String> queueMutation({
    required String operation,
    required Map<String, dynamic> payload,
    Function? optimisticUpdate,
  }) async {
    final mutation = PendingMutation(
      id: _uuid.v4(),
      operation: operation,
      payload: jsonEncode(payload),
      createdAt: DateTime.now(),
      status: 'pending',
    );

    if (optimisticUpdate != null) {
      optimisticUpdate();
    }

    await HiveService().addMutation(mutation);
    onMutationStatusChange?.call(mutation.id, 'pending');

    if (_isOnline) {
      _triggerSync();
    }

    return mutation.id;
  }

  Future<void> _triggerSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pending = HiveService().getPendingMutations();

      for (final mutation in pending) {
        await _processMutation(mutation);
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processMutation(PendingMutation mutation) async {
    try {
      mutation.status = 'syncing';
      await mutation.save();
      onMutationStatusChange?.call(mutation.id, 'syncing');

      final payload = jsonDecode(mutation.payload) as Map<String, dynamic>;

      switch (mutation.operation) {
        case 'claimJob':
          await ConvexService.instance.mutate('jobs:claimJob', {
            'jobId': payload['jobId'],
            'message': payload['message'],
          });
          break;

        case 'withdrawClaim':
          await ConvexService.instance.mutate('jobs:withdrawClaim', {
            'jobId': payload['jobId'],
          });
          break;

        default:
          throw Exception('Unknown operation: ${mutation.operation}');
      }

      mutation.status = 'completed';
      await mutation.save();
      onMutationStatusChange?.call(mutation.id, 'completed');
      log.i('[OfflineQueue] Mutation ${mutation.id} completed');
    } catch (e) {
      log.e('[OfflineQueue] Error: $e');
      await _handleError(mutation, e);
    }
  }

  Future<void> _handleError(PendingMutation mutation, dynamic error) async {
    await HiveService().incrementRetry(mutation.id);

    if (mutation.retryCount >= 3) {
      mutation.status = 'failed';
      await mutation.save();
      onMutationStatusChange?.call(mutation.id, 'failed');
      onShowNotification?.call('Failed to sync. Will retry later.');
    } else {
      mutation.status = 'pending';
      await mutation.save();
    }
  }

  Future<void> syncNow() async {
    await _checkConnectivity();
    if (_isOnline) {
      await _triggerSync();
    }
  }

  Map<String, int> getQueueStats() {
    final all = HiveService().mutationBox.values;
    return {
      'pending': all.where((m) => m.status == 'pending').length,
      'syncing': all.where((m) => m.status == 'syncing').length,
      'completed': all.where((m) => m.status == 'completed').length,
      'failed': all.where((m) => m.status == 'failed').length,
    };
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
