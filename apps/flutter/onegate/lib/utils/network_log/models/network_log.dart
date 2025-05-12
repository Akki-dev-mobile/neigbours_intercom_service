import 'package:hive/hive.dart';

part 'network_log.g.dart';

@HiveType(typeId: 1)
class NetworkLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String url;

  @HiveField(2)
  final String method;

  @HiveField(3)
  final Map<String, dynamic> headers;

  @HiveField(4)
  final String? requestBody;

  @HiveField(5)
  final int? statusCode;

  @HiveField(6)
  final String? responseBody;

  @HiveField(7)
  final String? error;

  @HiveField(8)
  final DateTime timestamp;

  @HiveField(9)
  final int duration; // in milliseconds

  @HiveField(10)
  final String gateId; // e.g., "MAIN_GATE", "TOWER_A_GATE"

  @HiveField(11)
  final String environment; // dev/staging/prod

  @HiveField(12)
  final bool synced; // Whether this log has been synced to the server

  NetworkLog({
    required this.id,
    required this.url,
    required this.method,
    required this.headers,
    this.requestBody,
    this.statusCode,
    this.responseBody,
    this.error,
    required this.timestamp,
    required this.duration,
    this.gateId = '',
    this.environment = '',
    this.synced = false,
  });

  // Helper method to create a log from a request
  static NetworkLog fromRequest({
    required String url,
    required String method,
    required Map<String, dynamic> headers,
    String? requestBody,
    required DateTime timestamp,
    String gateId = '',
    String environment = '',
  }) {
    return NetworkLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url,
      method: method,
      headers: headers,
      requestBody: requestBody,
      timestamp: timestamp,
      duration: 0,
      gateId: gateId,
      environment: environment,
      synced: false,
    );
  }

  // Helper method to update a log with response data
  NetworkLog withResponse({
    required int statusCode,
    required String responseBody,
    required int duration,
  }) {
    return NetworkLog(
      id: id,
      url: url,
      method: method,
      headers: headers,
      requestBody: requestBody,
      statusCode: statusCode,
      responseBody: responseBody,
      timestamp: timestamp,
      duration: duration,
      error: null,
      gateId: gateId,
      environment: environment,
      synced: synced,
    );
  }

  // Helper method to update a log with error data
  NetworkLog withError({
    required String error,
    required int duration,
  }) {
    return NetworkLog(
      id: id,
      url: url,
      method: method,
      headers: headers,
      requestBody: requestBody,
      timestamp: timestamp,
      duration: duration,
      error: error,
      gateId: gateId,
      environment: environment,
      synced: synced,
    );
  }

  // Helper method to mark a log as synced
  NetworkLog markAsSynced() {
    return NetworkLog(
      id: id,
      url: url,
      method: method,
      headers: headers,
      requestBody: requestBody,
      statusCode: statusCode,
      responseBody: responseBody,
      timestamp: timestamp,
      duration: duration,
      error: error,
      gateId: gateId,
      environment: environment,
      synced: true,
    );
  }

  // Helper method to get a short description of the log
  String get shortDescription {
    final statusText = statusCode != null ? '$statusCode' : 'Error';
    return '$method $url ($statusText)';
  }

  // Helper method to get a formatted timestamp
  String get formattedTimestamp {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  // Helper method to get a formatted duration
  String get formattedDuration {
    if (duration < 1000) {
      return '$duration ms';
    } else {
      return '${(duration / 1000).toStringAsFixed(2)} s';
    }
  }

  // Helper method to get a color based on status code
  int get statusColor {
    if (statusCode == null) {
      return 0xFFFF5252; // Red for errors
    } else if (statusCode! >= 200 && statusCode! < 300) {
      return 0xFF4CAF50; // Green for success
    } else if (statusCode! >= 300 && statusCode! < 400) {
      return 0xFF2196F3; // Blue for redirects
    } else if (statusCode! >= 400 && statusCode! < 500) {
      return 0xFFFF9800; // Orange for client errors
    } else {
      return 0xFFFF5252; // Red for server errors
    }
  }
}
