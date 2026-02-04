import 'package:hive_flutter/hive_flutter.dart';
import '../models/pending_mutation.dart';

class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();
  
  Box<PendingMutation>? _mutationBox;
  
  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(PendingMutationAdapter());
    _mutationBox = await Hive.openBox<PendingMutation>('pending_mutations');
  }
  
  Box<PendingMutation> get mutationBox {
    if (_mutationBox == null) {
      throw Exception('Hive not initialized. Call init() first.');
    }
    return _mutationBox!;
  }
  
  List<PendingMutation> getPendingMutations() {
    return mutationBox.values
        .where((m) => m.status == 'pending')
        .toList();
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
}
