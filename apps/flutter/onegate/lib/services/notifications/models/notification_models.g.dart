// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NotificationMessageAdapter extends TypeAdapter<NotificationMessage> {
  @override
  final int typeId = 100;

  @override
  NotificationMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NotificationMessage(
      id: fields[0] as String,
      topic: fields[1] as String,
      title: fields[2] as String,
      message: fields[3] as String,
      priority: fields[4] as int,
      tags: (fields[5] as List).cast<String>(),
      data: (fields[6] as Map).cast<String, dynamic>(),
      timestamp: fields[7] as DateTime,
      isRead: fields[8] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, NotificationMessage obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.topic)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.message)
      ..writeByte(4)
      ..write(obj.priority)
      ..writeByte(5)
      ..write(obj.tags)
      ..writeByte(6)
      ..write(obj.data)
      ..writeByte(7)
      ..write(obj.timestamp)
      ..writeByte(8)
      ..write(obj.isRead);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NotificationSubscriberAdapter extends TypeAdapter<NotificationSubscriber> {
  @override
  final int typeId = 101;

  @override
  NotificationSubscriber read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NotificationSubscriber(
      id: fields[0] as String,
      topic: fields[1] as String,
      webhookUrl: fields[2] as String?,
      deviceId: fields[3] as String?,
      metadata: (fields[4] as Map).cast<String, String>(),
      createdAt: fields[5] as DateTime,
      isActive: fields[6] as bool,
      lastDelivery: fields[7] as DateTime?,
      deliveryCount: fields[8] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, NotificationSubscriber obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.topic)
      ..writeByte(2)
      ..write(obj.webhookUrl)
      ..writeByte(3)
      ..write(obj.deviceId)
      ..writeByte(4)
      ..write(obj.metadata)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.lastDelivery)
      ..writeByte(8)
      ..write(obj.deliveryCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationSubscriberAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
