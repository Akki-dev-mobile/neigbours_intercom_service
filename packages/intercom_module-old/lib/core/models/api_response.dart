/// API Response wrapper class following SSO-Flutter patterns
/// Provides consistent response handling across all API services
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final String? message;
  final int? statusCode;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  ApiResponse._({
    required this.success,
    this.data,
    this.error,
    this.message,
    this.statusCode,
    this.metadata,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ApiResponse.success(
    T? data, {
    String? message,
    int? statusCode,
    Map<String, dynamic>? metadata,
  }) {
    return ApiResponse._(
      success: true,
      data: data,
      message: message,
      statusCode: statusCode ?? 200,
      metadata: metadata,
    );
  }

  factory ApiResponse.error(
    String error, {
    String? message,
    int? statusCode,
    Map<String, dynamic>? metadata,
  }) {
    return ApiResponse._(
      success: false,
      error: error,
      message: message,
      statusCode: statusCode,
      metadata: metadata,
    );
  }

  factory ApiResponse.failure(
    String message, {
    T? data,
    int? statusCode,
    Map<String, dynamic>? metadata,
  }) {
    return ApiResponse._(
      success: false,
      data: data,
      message: message,
      statusCode: statusCode ?? 400,
      metadata: metadata,
    );
  }

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    final success = json['success'] ?? json['status'] == 'success' ?? false;

    if (success) {
      T? data;
      if (fromJsonT != null && json['data'] != null) {
        try {
          data = fromJsonT(json['data']);
        } catch (e) {
          return ApiResponse.error(
            'Failed to parse response data: $e',
            statusCode: 500,
            metadata: {'original_data': json['data']},
          );
        }
      }

      return ApiResponse.success(
        data,
        message: json['message'],
        statusCode: json['status_code'],
        metadata: json['metadata'],
      );
    } else {
      return ApiResponse.error(
        json['error'] ?? json['message'] ?? 'Unknown error',
        message: json['message'],
        statusCode: json['status_code'],
        metadata: json['metadata'],
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data,
      'error': error,
      'message': message,
      'status_code': statusCode,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  bool get hasData => success && data != null;

  String get displayError {
    if (error != null) return error!;
    if (message != null) return message!;
    return 'An unexpected error occurred';
  }

  String get displayMessage {
    if (message != null) return message!;
    if (success) return 'Operation completed successfully';
    return displayError;
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? metadata;

  ApiException(
    this.message, {
    this.statusCode,
    this.metadata,
  });

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

