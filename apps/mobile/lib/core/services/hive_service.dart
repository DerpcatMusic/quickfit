import 'package:hive_flutter/hive_flutter.dart';
import '../models/pending_mutation.dart';

class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();

  Box<PendingMutation>? _mutationBox;
  Box? _cacheBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(PendingMutationAdapter());
    _mutationBox = await Hive.openBox<PendingMutation>('pending_mutations');
    _cacheBox = await Hive.openBox('app_cache');
  }

  Box<PendingMutation> get mutationBox {
    if (_mutationBox == null) {
      throw Exception('Hive not initialized. Call init() first.');
    }
    return _mutationBox!;
  }

  Box get cacheBox {
    if (_cacheBox == null) {
      throw Exception('Hive not initialized. Call init() first.');
    }
    return _cacheBox!;
  }

  // Generic Cache Methods
  Future<void> save(String key, dynamic data) async {
    await cacheBox.put(key, data);
  }

  dynamic get(String key) {
    if (_cacheBox == null) return null;
    return cacheBox.get(key);
  }

  List<PendingMutation> getPendingMutations() {
    return mutationBox.values.where((m) => m.status == 'pending').toList();
  }

  Future<void> addMutation(PendingMutation mutation) async {
    await mutationBox.put(mutation.id, mutation);
  }

  Future<void> markCompleted(String id) async {
    final mutation = mutationBox.get(id);
    if (mutation != null) {
      mutation.status = 'completed';
      await mutation.save();
    }
  }

  Future<void> markFailed(String id) async {
    final mutation = mutationBox.get(id);
    if (mutation != null) {
      mutation.status = 'failed';
      await mutation.save();
    }
  }

  Future<void> incrementRetry(String id) async {
    final mutation = mutationBox.get(id);
    if (mutation != null) {
      mutation.retryCount++;
      mutation.lastAttempt = DateTime.now();
      await mutation.save();
    }
  }

  Future<void> updateStatus(String id, String status) async {
    final mutation = mutationBox.get(id);
    if (mutation != null) {
      mutation.status = status;
      await mutation.save();
    }
  }

  Future<bool> acquireLock({
    required String key,
    required String owner,
    Duration ttl = const Duration(seconds: 30),
  }) async {
    final now = DateTime.now();
    final lock = cacheBox.get(key);
    if (lock is Map) {
      final lockOwner = lock['owner'] as String?;
      final expiresAtMs = lock['expiresAt'] as int?;
      if (lockOwner != null &&
          expiresAtMs != null &&
          DateTime.fromMillisecondsSinceEpoch(expiresAtMs).isAfter(now)) {
        return false;
      }
    }

    await cacheBox.put(key, {
      'owner': owner,
      'expiresAt': now.add(ttl).millisecondsSinceEpoch,
    });
    return true;
  }

  Future<void> refreshLock({
    required String key,
    required String owner,
    Duration ttl = const Duration(seconds: 30),
  }) async {
    final now = DateTime.now();
    await cacheBox.put(key, {
      'owner': owner,
      'expiresAt': now.add(ttl).millisecondsSinceEpoch,
    });
  }

  Future<void> releaseLock({
    required String key,
    required String owner,
  }) async {
    final lock = cacheBox.get(key);
    if (lock is Map && lock['owner'] == owner) {
      await cacheBox.delete(key);
    }
  }
}
