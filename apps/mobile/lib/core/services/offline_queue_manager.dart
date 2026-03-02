import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:uuid/uuid.dart';
import '../models/pending_mutation.dart';
import 'hive_service.dart';
import 'offline_mutation_runner.dart';
import '../utils/logger.dart';

class OfflineQueueManager {
  static final OfflineQueueManager _instance = OfflineQueueManager._internal();
  factory OfflineQueueManager() => _instance;
  OfflineQueueManager._internal();

  final _connectivity = Connectivity();
  final _uuid = const Uuid();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;
  bool _isOnline = false;

  Function(String mutationId, String status)? onMutationStatusChange;
  Function(String message)? onShowNotification;

  Future<void> initialize() async {
    await _checkConnectivity();

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
    final userUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (userUid == null || userUid.isEmpty) {
      throw Exception('Must be signed in to queue offline operations');
    }

    final mutation = PendingMutation(
      id: _uuid.v4(),
      operation: operation,
      payload: jsonEncode(payload),
      userUid: userUid,
      createdAt: DateTime.now(),
      status: 'pending',
    );

    if (optimisticUpdate != null) {
      optimisticUpdate();
    }

    await HiveService().addMutation(mutation);
    onMutationStatusChange?.call(mutation.id, 'pending');

    await _checkConnectivity();
    if (_isOnline) {
      _triggerSync();
    }

    return mutation.id;
  }

  Future<void> _triggerSync() async {
    if (_isSyncing) return;
    await _checkConnectivity();
    if (!_isOnline) return;
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final syncUid = user.uid;
    _isSyncing = true;

    try {
      await ConvexClient.instance.setAuthWithRefresh(
        fetchToken: () async => await user.getIdToken(),
      );
      if (!ConvexClient.instance.isConnected) {
        await ConvexClient.instance.connectionState
            .firstWhere((s) => s == WebSocketConnectionState.connected)
            .timeout(const Duration(seconds: 15));
      }

      final latestUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (latestUser == null || latestUser.uid != syncUid) {
        return;
      }

      await OfflineMutationRunner.runPending(
        userUid: syncUid,
        onStatusChange: onMutationStatusChange,
        onShowNotification: onShowNotification,
      );
    } finally {
      _isSyncing = false;
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
