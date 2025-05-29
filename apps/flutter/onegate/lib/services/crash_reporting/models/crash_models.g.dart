// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crash_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CrashReportAdapter extends TypeAdapter<CrashReport> {
  @override
  final int typeId = 102;

  @override
  CrashReport read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CrashReport(
      id: fields[0] as String,
      errorMessage: fields[1] as String,
      stackTrace: fields[2] as String,
      timestamp: fields[3] as DateTime,
      appVersion: fields[4] as String,
      buildNumber: fields[5] as String,
      platform: fields[6] as String,
      osVersion: fields[7] as String,
      deviceModel: fields[8] as String,
      deviceId: fields[9] as String,
      isFatal: fields[10] as bool,
      customKeys: (fields[11] as Map).cast<String, dynamic>(),
      userId: fields[12] as String?,
      gateId: fields[13] as String?,
      sessionId: fields[14] as String?,
      isSynced: fields[15] as bool,
      errorType: fields[16] as String,
      errorSignature: fields[17] as String?,
      breadcrumbs: (fields[18] as Map).cast<String, dynamic>(),
      crashCount: fields[19] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CrashReport obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.errorMessage)
      ..writeByte(2)
      ..write(obj.stackTrace)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.appVersion)
      ..writeByte(5)
      ..write(obj.buildNumber)
      ..writeByte(6)
      ..write(obj.platform)
      ..writeByte(7)
      ..write(obj.osVersion)
      ..writeByte(8)
      ..write(obj.deviceModel)
      ..writeByte(9)
      ..write(obj.deviceId)
      ..writeByte(10)
      ..write(obj.isFatal)
      ..writeByte(11)
      ..write(obj.customKeys)
      ..writeByte(12)
      ..write(obj.userId)
      ..writeByte(13)
      ..write(obj.gateId)
      ..writeByte(14)
      ..write(obj.sessionId)
      ..writeByte(15)
      ..write(obj.isSynced)
      ..writeByte(16)
      ..write(obj.errorType)
      ..writeByte(17)
      ..write(obj.errorSignature)
      ..writeByte(18)
      ..write(obj.breadcrumbs)
      ..writeByte(19)
      ..write(obj.crashCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrashReportAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AnalyticsEventAdapter extends TypeAdapter<AnalyticsEvent> {
  @override
  final int typeId = 103;

  @override
  AnalyticsEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AnalyticsEvent(
      id: fields[0] as String,
      eventName: fields[1] as String,
      parameters: (fields[2] as Map).cast<String, dynamic>(),
      timestamp: fields[3] as DateTime,
      userId: fields[4] as String?,
      gateId: fields[5] as String?,
      sessionId: fields[6] as String?,
      isSynced: fields[7] as bool,
      eventCategory: fields[8] as String,
      duration: fields[9] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, AnalyticsEvent obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.eventName)
      ..writeByte(2)
      ..write(obj.parameters)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.userId)
      ..writeByte(5)
      ..write(obj.gateId)
      ..writeByte(6)
      ..write(obj.sessionId)
      ..writeByte(7)
      ..write(obj.isSynced)
      ..writeByte(8)
      ..write(obj.eventCategory)
      ..writeByte(9)
      ..write(obj.duration);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalyticsEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserSessionAdapter extends TypeAdapter<UserSession> {
  @override
  final int typeId = 104;

  @override
  UserSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserSession(
      sessionId: fields[0] as String,
      startTime: fields[1] as DateTime,
      endTime: fields[2] as DateTime?,
      userId: fields[3] as String?,
      gateId: fields[4] as String?,
      appVersion: fields[5] as String,
      platform: fields[6] as String,
      isSynced: fields[7] as bool,
      eventCount: fields[8] as int,
      crashCount: fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, UserSession obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.sessionId)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.userId)
      ..writeByte(4)
      ..write(obj.gateId)
      ..writeByte(5)
      ..write(obj.appVersion)
      ..writeByte(6)
      ..write(obj.platform)
      ..writeByte(7)
      ..write(obj.isSynced)
      ..writeByte(8)
      ..write(obj.eventCount)
      ..writeByte(9)
      ..write(obj.crashCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
