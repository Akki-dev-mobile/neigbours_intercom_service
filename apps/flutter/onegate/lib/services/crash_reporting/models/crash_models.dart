import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

part 'crash_models.g.dart';

/// Crash report data model
@HiveType(typeId: 102)
class CrashReport extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String errorMessage;

  @HiveField(2)
  final String stackTrace;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final String appVersion;

  @HiveField(5)
  final String buildNumber;

  @HiveField(6)
  final String platform;

  @HiveField(7)
  final String osVersion;

  @HiveField(8)
  final String deviceModel;

  @HiveField(9)
  final String deviceId;

  @HiveField(10)
  final bool isFatal;

  @HiveField(11)
  final Map<String, dynamic> customKeys;

  @HiveField(12)
  final String? userId;

  @HiveField(13)
  final String? gateId;

  @HiveField(14)
  final String? sessionId;

  @HiveField(15)
  final bool isSynced;

  @HiveField(16)
  final String errorType;

  @HiveField(17)
  final String? errorSignature;

  @HiveField(18)
  final Map<String, dynamic> breadcrumbs;

  @HiveField(19)
  final int crashCount;

  CrashReport({
    required this.id,
    required this.errorMessage,
    required this.stackTrace,
    required this.timestamp,
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.osVersion,
    required this.deviceModel,
    required this.deviceId,
    required this.isFatal,
    required this.customKeys,
    this.userId,
    this.gateId,
    this.sessionId,
    this.isSynced = false,
    required this.errorType,
    this.errorSignature,
    required this.breadcrumbs,
    this.crashCount = 1,
  });

  /// Generate error signature for grouping similar crashes
  String generateErrorSignature() {
    final cleanStackTrace = stackTrace
        .split('\n')
        .take(5) // Take first 5 lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('|');
    
    return '${errorType}_${errorMessage.hashCode}_${cleanStackTrace.hashCode}';
  }

  /// Convert to JSON for API sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'errorMessage': errorMessage,
      'stackTrace': stackTrace,
      'timestamp': timestamp.toIso8601String(),
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'platform': platform,
      'osVersion': osVersion,
      'deviceModel': deviceModel,
      'deviceId': deviceId,
      'isFatal': isFatal,
      'customKeys': customKeys,
      'userId': userId,
      'gateId': gateId,
      'sessionId': sessionId,
      'errorType': errorType,
      'errorSignature': errorSignature ?? generateErrorSignature(),
      'breadcrumbs': breadcrumbs,
      'crashCount': crashCount,
    };
  }

  /// Create from JSON
  factory CrashReport.fromJson(Map<String, dynamic> json) {
    return CrashReport(
      id: json['id'],
      errorMessage: json['errorMessage'],
      stackTrace: json['stackTrace'],
      timestamp: DateTime.parse(json['timestamp']),
      appVersion: json['appVersion'],
      buildNumber: json['buildNumber'],
      platform: json['platform'],
      osVersion: json['osVersion'],
      deviceModel: json['deviceModel'],
      deviceId: json['deviceId'],
      isFatal: json['isFatal'],
      customKeys: Map<String, dynamic>.from(json['customKeys'] ?? {}),
      userId: json['userId'],
      gateId: json['gateId'],
      sessionId: json['sessionId'],
      isSynced: json['isSynced'] ?? false,
      errorType: json['errorType'],
      errorSignature: json['errorSignature'],
      breadcrumbs: Map<String, dynamic>.from(json['breadcrumbs'] ?? {}),
      crashCount: json['crashCount'] ?? 1,
    );
  }

  /// Copy with updated fields
  CrashReport copyWith({
    bool? isSynced,
    int? crashCount,
    String? errorSignature,
  }) {
    return CrashReport(
      id: id,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      timestamp: timestamp,
      appVersion: appVersion,
      buildNumber: buildNumber,
      platform: platform,
      osVersion: osVersion,
      deviceModel: deviceModel,
      deviceId: deviceId,
      isFatal: isFatal,
      customKeys: customKeys,
      userId: userId,
      gateId: gateId,
      sessionId: sessionId,
      isSynced: isSynced ?? this.isSynced,
      errorType: errorType,
      errorSignature: errorSignature ?? this.errorSignature,
      breadcrumbs: breadcrumbs,
      crashCount: crashCount ?? this.crashCount,
    );
  }

  /// Get formatted timestamp
  String get formattedTimestamp {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  /// Get crash severity
  CrashSeverity get severity {
    if (isFatal) return CrashSeverity.fatal;
    if (errorType.toLowerCase().contains('error')) return CrashSeverity.error;
    if (errorType.toLowerCase().contains('warning')) return CrashSeverity.warning;
    return CrashSeverity.info;
  }
}

/// Analytics event data model
@HiveType(typeId: 103)
class AnalyticsEvent extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String eventName;

  @HiveField(2)
  final Map<String, dynamic> parameters;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final String? userId;

  @HiveField(5)
  final String? gateId;

  @HiveField(6)
  final String? sessionId;

  @HiveField(7)
  final bool isSynced;

  @HiveField(8)
  final String eventCategory;

  @HiveField(9)
  final int? duration;

  AnalyticsEvent({
    required this.id,
    required this.eventName,
    required this.parameters,
    required this.timestamp,
    this.userId,
    this.gateId,
    this.sessionId,
    this.isSynced = false,
    required this.eventCategory,
    this.duration,
  });

  /// Convert to JSON for API sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventName': eventName,
      'parameters': parameters,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'gateId': gateId,
      'sessionId': sessionId,
      'eventCategory': eventCategory,
      'duration': duration,
    };
  }

  /// Create from JSON
  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      id: json['id'],
      eventName: json['eventName'],
      parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
      timestamp: DateTime.parse(json['timestamp']),
      userId: json['userId'],
      gateId: json['gateId'],
      sessionId: json['sessionId'],
      isSynced: json['isSynced'] ?? false,
      eventCategory: json['eventCategory'],
      duration: json['duration'],
    );
  }

  /// Copy with updated sync status
  AnalyticsEvent copyWith({bool? isSynced}) {
    return AnalyticsEvent(
      id: id,
      eventName: eventName,
      parameters: parameters,
      timestamp: timestamp,
      userId: userId,
      gateId: gateId,
      sessionId: sessionId,
      isSynced: isSynced ?? this.isSynced,
      eventCategory: eventCategory,
      duration: duration,
    );
  }

  /// Get formatted timestamp
  String get formattedTimestamp {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

/// User session data model
@HiveType(typeId: 104)
class UserSession extends HiveObject {
  @HiveField(0)
  final String sessionId;

  @HiveField(1)
  final DateTime startTime;

  @HiveField(2)
  final DateTime? endTime;

  @HiveField(3)
  final String? userId;

  @HiveField(4)
  final String? gateId;

  @HiveField(5)
  final String appVersion;

  @HiveField(6)
  final String platform;

  @HiveField(7)
  final bool isSynced;

  @HiveField(8)
  final int eventCount;

  @HiveField(9)
  final int crashCount;

  UserSession({
    required this.sessionId,
    required this.startTime,
    this.endTime,
    this.userId,
    this.gateId,
    required this.appVersion,
    required this.platform,
    this.isSynced = false,
    this.eventCount = 0,
    this.crashCount = 0,
  });

  /// Get session duration
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Convert to JSON for API sync
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'userId': userId,
      'gateId': gateId,
      'appVersion': appVersion,
      'platform': platform,
      'duration': duration.inMilliseconds,
      'eventCount': eventCount,
      'crashCount': crashCount,
    };
  }

  /// Copy with updated fields
  UserSession copyWith({
    DateTime? endTime,
    bool? isSynced,
    int? eventCount,
    int? crashCount,
  }) {
    return UserSession(
      sessionId: sessionId,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      userId: userId,
      gateId: gateId,
      appVersion: appVersion,
      platform: platform,
      isSynced: isSynced ?? this.isSynced,
      eventCount: eventCount ?? this.eventCount,
      crashCount: crashCount ?? this.crashCount,
    );
  }
}

/// Crash severity levels
enum CrashSeverity {
  fatal,
  error,
  warning,
  info,
}

extension CrashSeverityExtension on CrashSeverity {
  String get displayName {
    switch (this) {
      case CrashSeverity.fatal:
        return 'Fatal';
      case CrashSeverity.error:
        return 'Error';
      case CrashSeverity.warning:
        return 'Warning';
      case CrashSeverity.info:
        return 'Info';
    }
  }

  String get colorHex {
    switch (this) {
      case CrashSeverity.fatal:
        return '#D32F2F'; // Red
      case CrashSeverity.error:
        return '#F57C00'; // Orange
      case CrashSeverity.warning:
        return '#FBC02D'; // Yellow
      case CrashSeverity.info:
        return '#1976D2'; // Blue
    }
  }
}

/// Analytics event categories
enum EventCategory {
  userAction,
  navigation,
  performance,
  error,
  system,
}

extension EventCategoryExtension on EventCategory {
  String get displayName {
    switch (this) {
      case EventCategory.userAction:
        return 'User Action';
      case EventCategory.navigation:
        return 'Navigation';
      case EventCategory.performance:
        return 'Performance';
      case EventCategory.error:
        return 'Error';
      case EventCategory.system:
        return 'System';
    }
  }
}
