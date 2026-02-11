import 'dart:convert';

import 'package:convex_flutter/convex_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/pending_mutation.dart';
import '../utils/logger.dart';
import 'hive_service.dart';

class OfflineMutationRunner {
  static const _lockKey = 'offline_mutation_runner_lock';
  static const _maxRetries = 3;
  static final _uuid = const Uuid();

  static Future<void> runPending({
    required String userUid,
    Function(String mutationId, String status)? onStatusChange,
    Function(String message)? onShowNotification,
  }) async {
    final owner = _uuid.v4();
    final hive = HiveService();
    final gotLock = await hive.acquireLock(key: _lockKey, owner: owner);
    if (!gotLock) {
      return;
    }

    try {
      final pending = hive.getPendingMutations(userUid: userUid);
      for (final mutation in pending) {
        await hive.refreshLock(key: _lockKey, owner: owner);
        await _processOne(
          mutation,
          onStatusChange: onStatusChange,
          onShowNotification: onShowNotification,
        );
      }
    } finally {
      await hive.releaseLock(key: _lockKey, owner: owner);
    }
  }

  static Future<void> _processOne(
    PendingMutation mutation, {
    Function(String mutationId, String status)? onStatusChange,
    Function(String message)? onShowNotification,
  }) async {
    if (mutation.status == 'syncing' || mutation.status == 'completed') {
      return;
    }

    try {
      mutation.status = 'syncing';
      mutation.lastAttempt = DateTime.now();
      await mutation.save();
      onStatusChange?.call(mutation.id, 'syncing');

      final decoded = mutation.payload;
      final args = decoded.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(decoded) as Map)
          : <String, dynamic>{};

      switch (mutation.operation) {
        case 'claimJob':
          await ConvexClient.instance.mutation(
            name: 'jobs:claimJob',
            args: {
              'jobId': args['jobId'],
              if (args['message'] != null) 'message': args['message'],
              'idempotencyKey': mutation.id,
            },
          );
          break;
        case 'withdrawClaim':
          await ConvexClient.instance.mutation(
            name: 'jobs:withdrawClaim',
            args: {
              'jobId': args['jobId'],
              'idempotencyKey': mutation.id,
            },
          );
          break;
        default:
          throw Exception('Unknown operation: ${mutation.operation}');
      }

      mutation.status = 'completed';
      await mutation.save();
      onStatusChange?.call(mutation.id, 'completed');
      log.i('[OfflineRunner] Mutation ${mutation.id} completed');
    } catch (e) {
      log.e('[OfflineRunner] Mutation ${mutation.id} failed: $e');
      mutation.retryCount += 1;
      mutation.lastAttempt = DateTime.now();
      if (mutation.retryCount >= _maxRetries) {
        mutation.status = 'failed';
        onStatusChange?.call(mutation.id, 'failed');
        onShowNotification?.call('Failed to sync. Will retry later.');
      } else {
        mutation.status = 'pending';
      }
      await mutation.save();
    }
  }
}
