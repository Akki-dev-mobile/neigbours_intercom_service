import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';

/// SkyWalking distributed tracing service for service mesh monitoring
class SkyWalkingTracingService {
  static SkyWalkingTracingService? _instance;
  static SkyWalkingTracingService get instance => _instance ??= SkyWalkingTracingService._();
  
  SkyWalkingTracingService._();

  bool _isInitialized = false;
  Dio? _dio;
  String? _endpoint;
  String? _serviceName;
  String? _serviceInstance;
  final Uuid _uuid = const Uuid();
  final Map<String, SkyWalkingSpan> _activeSpans = {};

  /// Initialize SkyWalking tracing service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load environment variables
      await dotenv.load(fileName: ".env");
      
      _endpoint = dotenv.env['SKYWALKING_ENDPOINT'] ?? 'http://localhost:11800';
      _serviceName = 'onegate-flutter';
      _serviceInstance = 'onegate-instance-${_generateInstanceId()}';

      // Initialize Dio client
      _dio = Dio(BaseOptions(
        baseUrl: _endpoint!,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
        },
      ));

      _isInitialized = true;
      dev.log('SkyWalking tracing service initialized successfully');

      // Send service registration
      await _registerService();

      // Start a root span for initialization
      final initSpan = startSpan(
        operationName: 'service_initialization',
        spanType: SkyWalkingSpanType.entry,
      );
      initSpan.setTag('service.name', _serviceName!);
      initSpan.setTag('service.instance', _serviceInstance!);
      initSpan.finish();

    } catch (e, stackTrace) {
      dev.log('Error initializing SkyWalking tracing service: $e');
      dev.log('Stack trace: $stackTrace');
    }
  }

  /// Register service with SkyWalking
  Future<void> _registerService() async {
    if (_dio == null) return;

    try {
      final registrationData = {
        'service': _serviceName,
        'serviceInstance': _serviceInstance,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'properties': {
          'platform': defaultTargetPlatform.name,
          'language': 'dart',
          'framework': 'flutter',
          'version': '1.0.0',
        },
      };

      await _dio!.post('/v3/management/reportProperties', data: jsonEncode(registrationData));
      dev.log('Service registered with SkyWalking: $_serviceName');
    } catch (e) {
      dev.log('Error registering service with SkyWalking: $e');
    }
  }

  /// Start a new span
  SkyWalkingSpan startSpan({
    required String operationName,
    SkyWalkingSpanType spanType = SkyWalkingSpanType.local,
    String? parentSpanId,
    Map<String, dynamic>? tags,
  }) {
    if (!_isInitialized) {
      return SkyWalkingSpan.noop();
    }

    final span = SkyWalkingSpan(
      traceId: _generateTraceId(),
      spanId: _generateSpanId(),
      parentSpanId: parentSpanId,
      operationName: operationName,
      serviceName: _serviceName!,
      serviceInstance: _serviceInstance!,
      spanType: spanType,
      startTime: DateTime.now().millisecondsSinceEpoch,
    );

    if (tags != null) {
      tags.forEach((key, value) => span.setTag(key, value));
    }

    _activeSpans[span.spanId] = span;
    return span;
  }

  /// Finish a span and send to SkyWalking
  Future<void> finishSpan(SkyWalkingSpan span) async {
    if (!_isInitialized || _dio == null) return;

    try {
      _activeSpans.remove(span.spanId);
      
      final spanData = span.toJson();
      await _sendSpan(spanData);
    } catch (e) {
      dev.log('Error finishing span: $e');
    }
  }

  /// Send span data to SkyWalking
  Future<void> _sendSpan(Map<String, dynamic> spanData) async {
    if (_dio == null) return;

    try {
      final payload = {
        'spans': [spanData],
        'service': _serviceName,
        'serviceInstance': _serviceInstance,
      };

      await _dio!.post('/v3/segments', data: jsonEncode(payload));
      dev.log('Span sent to SkyWalking: ${spanData['operationName']}');
    } catch (e) {
      dev.log('Error sending span to SkyWalking: $e');
    }
  }

  /// Trace a network request
  Future<T> traceNetworkRequest<T>({
    required String method,
    required String url,
    required Future<T> Function() request,
    Map<String, dynamic>? tags,
  }) async {
    final span = startSpan(
      operationName: '$method $url',
      spanType: SkyWalkingSpanType.exit,
      tags: {
        'http.method': method,
        'http.url': url,
        'component': 'http_client',
        ...?tags,
      },
    );

    try {
      final result = await request();
      span.setTag('http.status_code', 200);
      return result;
    } catch (e) {
      span.setTag('error', true);
      span.setTag('error.message', e.toString());
      span.setTag('http.status_code', 500);
      rethrow;
    } finally {
      span.finish();
      await finishSpan(span);
    }
  }

  /// Trace a database operation
  Future<T> traceDatabaseOperation<T>({
    required String operation,
    required String table,
    required Future<T> Function() dbOperation,
    Map<String, dynamic>? tags,
  }) async {
    final span = startSpan(
      operationName: '$operation $table',
      spanType: SkyWalkingSpanType.exit,
      tags: {
        'db.type': 'sqlite',
        'db.statement': operation,
        'db.table': table,
        'component': 'database',
        ...?tags,
      },
    );

    try {
      final result = await dbOperation();
      return result;
    } catch (e) {
      span.setTag('error', true);
      span.setTag('error.message', e.toString());
      rethrow;
    } finally {
      span.finish();
      await finishSpan(span);
    }
  }

  /// Trace a user action
  Future<T> traceUserAction<T>({
    required String action,
    required String screen,
    required Future<T> Function() userAction,
    Map<String, dynamic>? tags,
  }) async {
    final span = startSpan(
      operationName: 'user_action_$action',
      spanType: SkyWalkingSpanType.local,
      tags: {
        'user.action': action,
        'screen.name': screen,
        'component': 'user_interface',
        ...?tags,
      },
    );

    try {
      final result = await userAction();
      return result;
    } catch (e) {
      span.setTag('error', true);
      span.setTag('error.message', e.toString());
      rethrow;
    } finally {
      span.finish();
      await finishSpan(span);
    }
  }

  /// Generate a unique trace ID
  String _generateTraceId() {
    return _uuid.v4().replaceAll('-', '');
  }

  /// Generate a unique span ID
  String _generateSpanId() {
    return DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  }

  /// Generate a unique instance ID
  String _generateInstanceId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Get active spans count
  int get activeSpansCount => _activeSpans.length;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose resources
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      // Finish all active spans
      for (final span in _activeSpans.values) {
        span.finish();
        await finishSpan(span);
      }
      _activeSpans.clear();

      // Close Dio client
      _dio?.close();
      _dio = null;

      _isInitialized = false;
      dev.log('SkyWalking tracing service disposed');
    } catch (e) {
      dev.log('Error disposing SkyWalking tracing service: $e');
    }
  }
}

/// SkyWalking span types
enum SkyWalkingSpanType {
  entry,  // Entry span (server side)
  exit,   // Exit span (client side)
  local,  // Local span (internal operation)
}

/// SkyWalking span implementation
class SkyWalkingSpan {
  final String traceId;
  final String spanId;
  final String? parentSpanId;
  final String operationName;
  final String serviceName;
  final String serviceInstance;
  final SkyWalkingSpanType spanType;
  final int startTime;
  
  int? endTime;
  final Map<String, dynamic> tags = {};
  final List<Map<String, dynamic>> logs = [];
  bool isFinished = false;

  SkyWalkingSpan({
    required this.traceId,
    required this.spanId,
    this.parentSpanId,
    required this.operationName,
    required this.serviceName,
    required this.serviceInstance,
    required this.spanType,
    required this.startTime,
  });

  /// Create a no-op span for when service is not initialized
  factory SkyWalkingSpan.noop() {
    return SkyWalkingSpan(
      traceId: 'noop',
      spanId: 'noop',
      operationName: 'noop',
      serviceName: 'noop',
      serviceInstance: 'noop',
      spanType: SkyWalkingSpanType.local,
      startTime: 0,
    );
  }

  /// Set a tag on the span
  void setTag(String key, dynamic value) {
    if (isFinished) return;
    tags[key] = value;
  }

  /// Add a log entry to the span
  void log(String message, {Map<String, dynamic>? fields}) {
    if (isFinished) return;
    
    logs.add({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'message': message,
      'fields': fields ?? {},
    });
  }

  /// Finish the span
  void finish() {
    if (isFinished) return;
    
    endTime = DateTime.now().millisecondsSinceEpoch;
    isFinished = true;
  }

  /// Convert span to JSON for SkyWalking
  Map<String, dynamic> toJson() {
    return {
      'traceId': traceId,
      'spanId': spanId,
      'parentSpanId': parentSpanId,
      'operationName': operationName,
      'serviceName': serviceName,
      'serviceInstance': serviceInstance,
      'spanType': spanType.index,
      'startTime': startTime,
      'endTime': endTime ?? DateTime.now().millisecondsSinceEpoch,
      'tags': tags,
      'logs': logs,
      'isError': tags.containsKey('error') && tags['error'] == true,
    };
  }
}
