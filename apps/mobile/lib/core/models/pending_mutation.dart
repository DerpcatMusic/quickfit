import 'package:hive/hive.dart';

part 'pending_mutation.g.dart';

@HiveType(typeId: 1)
class PendingMutation extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String operation;
  
  @HiveField(2)
  final String payload;
  
  @HiveField(3)
  final DateTime createdAt;
  
  @HiveField(4)
  int retryCount;
  
  @HiveField(5)
  String status;
  
  @HiveField(6)
  DateTime? lastAttempt;
  
  PendingMutation({
    required this.id,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.status = 'pending',
    this.lastAttempt,
  });
}
