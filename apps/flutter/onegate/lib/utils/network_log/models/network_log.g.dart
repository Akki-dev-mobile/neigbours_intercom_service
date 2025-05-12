// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NetworkLogAdapter extends TypeAdapter<NetworkLog> {
  @override
  final int typeId = 1;

  @override
  NetworkLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NetworkLog(
      id: fields[0] as String,
      url: fields[1] as String,
      method: fields[2] as String,
      headers: (fields[3] as Map).cast<String, dynamic>(),
      requestBody: fields[4] as String?,
      statusCode: fields[5] as int?,
      responseBody: fields[6] as String?,
      error: fields[7] as String?,
      timestamp: fields[8] as DateTime,
      duration: fields[9] as int,
      gateId: fields[10] as String,
      environment: fields[11] as String,
      synced: fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, NetworkLog obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.url)
      ..writeByte(2)
      ..write(obj.method)
      ..writeByte(3)
      ..write(obj.headers)
      ..writeByte(4)
      ..write(obj.requestBody)
      ..writeByte(5)
      ..write(obj.statusCode)
      ..writeByte(6)
      ..write(obj.responseBody)
      ..writeByte(7)
      ..write(obj.error)
      ..writeByte(8)
      ..write(obj.timestamp)
      ..writeByte(9)
      ..write(obj.duration)
      ..writeByte(10)
      ..write(obj.gateId)
      ..writeByte(11)
      ..write(obj.environment)
      ..writeByte(12)
      ..write(obj.synced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
