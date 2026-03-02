import 'package:hive/hive.dart';

/// Manual Hive adapter for PendingMutation
/// (No code generation required)
class PendingMutation extends HiveObject {
  late String id;
  late String operation;
  late String payload;
  String? userUid;
  late DateTime createdAt;
  late int retryCount;
  late String status;
  DateTime? lastAttempt;

  PendingMutation({
    required this.id,
    required this.operation,
    required this.payload,
    this.userUid,
    required this.createdAt,
    this.retryCount = 0,
    this.status = 'pending',
    this.lastAttempt,
  });
}

/// Manual Hive TypeAdapter for PendingMutation
class PendingMutationAdapter extends TypeAdapter<PendingMutation> {
  @override
  final int typeId = 1;

  @override
  PendingMutation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingMutation(
      id: fields[0] as String,
      operation: fields[1] as String,
      payload: fields[2] as String,
      userUid: fields[7] as String?,
      createdAt: fields[3] as DateTime,
      retryCount: fields[4] as int,
      status: fields[5] as String,
      lastAttempt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PendingMutation obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.operation)
      ..writeByte(2)
      ..write(obj.payload)
      ..writeByte(7)
      ..write(obj.userUid)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.retryCount)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.lastAttempt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingMutationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
