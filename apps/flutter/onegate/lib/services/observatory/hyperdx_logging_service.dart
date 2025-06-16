import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// HyperDX logging service for structured log aggregation and session replay
class HyperDxLoggingService {
  static HyperDxLoggingService? _instance;
  static HyperDxLoggingService get instance => _instance ??= HyperDxLoggingService._();
  
  HyperDxLoggingService._();

  bool _isInitialized = false;
  Dio? _dio;
  String? _endpoint;
  String? _apiKey;
  Timer? _batchTimer;
  Box<Map>? _logBox;
  final List<Map<String, dynamic>> _logBuffer = [];
  final int _maxBufferSize = 100;
  final Duration _batchInterval = const Duration(seconds: 30);

  /// Initialize HyperDX logging service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load environment variables
      await dotenv.load(fileName: ".env");
      
      _endpoint = dotenv.env['HYPERDX_ENDPOINT'] ?? 'http://localhost:8080';
      _apiKey = dotenv.env['HYPERDX_API_KEY'];
      
      if (_apiKey == null || _apiKey!.isEmpty) {
        dev.log('HyperDX API key not configured, using local endpoint only');
      }

      // Initialize Hive storage for offline logs
      _logBox = await Hive.openBox<Map>('hyperdx_logs');

      // Initialize Dio client
      _dio = Dio(BaseOptions(
        baseUrl: _endpoint!,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
        },
      ));

      // Start batch processing
      _startBatchProcessing();

      // Send any stored offline logs
      await _sendStoredLogs();

      _isInitialized = true;
      dev.log('HyperDX logging service initialized successfully');

      // Log initialization event
      await logEvent(
        level: 'info',
        message: 'HyperDX logging service initialized',
        category: 'system',
        metadata: {
          'endpoint': _endpoint,
          'has_api_key': _apiKey != null,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

    } catch (e, stackTrace) {
      dev.log('Error initializing HyperDX logging service: $e');
      dev.log('Stack trace: $stackTrace');
    }
  }

  /// Start batch processing timer
  void _startBatchProcessing() {
    _batchTimer = Timer.periodic(_batchInterval, (_) {
      _processBatch();
    });
  }

  /// Process and send batched logs
  Future<void> _processBatch() async {
    if (_logBuffer.isEmpty || !_isInitialized || _dio == null) return;

    final logsToSend = List<Map<String, dynamic>>.from(_logBuffer);
    _logBuffer.clear();

    try {
      await _sendLogs(logsToSend);
    } catch (e) {
      // Store failed logs for retry
      await _storeLogs(logsToSend);
      dev.log('Error sending logs to HyperDX, stored for retry: $e');
    }
  }

  /// Send logs to HyperDX
  Future<void> _sendLogs(List<Map<String, dynamic>> logs) async {
    if (_dio == null || logs.isEmpty) return;

    try {
      final payload = {
        'logs': logs,
        'source': 'onegate-flutter',
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _dio!.post('/api/logs', data: jsonEncode(payload));
      dev.log('Successfully sent ${logs.length} logs to HyperDX');
    } catch (e) {
      dev.log('Error sending logs to HyperDX: $e');
      rethrow;
    }
  }

  /// Store logs locally for offline retry
  Future<void> _storeLogs(List<Map<String, dynamic>> logs) async {
    if (_logBox == null) return;

    try {
      for (final log in logs) {
        final key = 'log_${DateTime.now().millisecondsSinceEpoch}_${log.hashCode}';
        await _logBox!.put(key, log);
      }
    } catch (e) {
      dev.log('Error storing logs locally: $e');
    }
  }

  /// Send stored offline logs
  Future<void> _sendStoredLogs() async {
    if (_logBox == null || _logBox!.isEmpty) return;

    try {
      final storedLogs = _logBox!.values.map((log) => Map<String, dynamic>.from(log)).toList();
      
      if (storedLogs.isNotEmpty) {
        await _sendLogs(storedLogs);
        await _logBox!.clear();
        dev.log('Sent ${storedLogs.length} stored logs to HyperDX');
      }
    } catch (e) {
      dev.log('Error sending stored logs: $e');
    }
  }

  /// Log an event with structured data
  Future<void> logEvent({
    required String level,
    required String message,
    String? category,
    Map<String, dynamic>? metadata,
    String? sessionId,
    String? userId,
  }) async {
    if (!_isInitialized) {
      dev.log('HyperDX not initialized, logging locally: $message');
      return;
    }

    final logEntry = {
      'timestamp': DateTime.now().toIso8601String(),
      'level': level,
      'message': message,
      'category': category ?? 'general',
      'service': 'onegate-flutter',
      'platform': defaultTargetPlatform.name,
      'session_id': sessionId,
      'user_id': userId,
      'metadata': metadata ?? {},
    };

    _logBuffer.add(logEntry);

    // Send immediately if buffer is full
    if (_logBuffer.length >= _maxBufferSize) {
      await _processBatch();
    }
  }

  /// Log an error with stack trace
  Future<void> logError({
    required String message,
    dynamic error,
    StackTrace? stackTrace,
    String? category,
    Map<String, dynamic>? metadata,
    String? sessionId,
    String? userId,
  }) async {
    await logEvent(
      level: 'error',
      message: message,
      category: category ?? 'error',
      metadata: {
        'error': error?.toString(),
        'stack_trace': stackTrace?.toString(),
        ...?metadata,
      },
      sessionId: sessionId,
      userId: userId,
    );
  }

  /// Log a warning
  Future<void> logWarning({
    required String message,
    String? category,
    Map<String, dynamic>? metadata,
    String? sessionId,
    String? userId,
  }) async {
    await logEvent(
      level: 'warning',
      message: message,
      category: category ?? 'warning',
      metadata: metadata,
      sessionId: sessionId,
      userId: userId,
    );
  }

  /// Log an info message
  Future<void> logInfo({
    required String message,
    String? category,
    Map<String, dynamic>? metadata,
    String? sessionId,
    String? userId,
  }) async {
    await logEvent(
      level: 'info',
      message: message,
      category: category ?? 'info',
      metadata: metadata,
      sessionId: sessionId,
      userId: userId,
    );
  }

  /// Log a debug message
  Future<void> logDebug({
    required String message,
    String? category,
    Map<String, dynamic>? metadata,
    String? sessionId,
    String? userId,
  }) async {
    if (!kDebugMode) return; // Only log debug messages in debug mode

    await logEvent(
      level: 'debug',
      message: message,
      category: category ?? 'debug',
      metadata: metadata,
      sessionId: sessionId,
      userId: userId,
    );
  }

  /// Log network request
  Future<void> logNetworkRequest({
    required String method,
    required String url,
    int? statusCode,
    Duration? duration,
    Map<String, dynamic>? requestData,
    Map<String, dynamic>? responseData,
    String? sessionId,
    String? userId,
  }) async {
    await logEvent(
      level: statusCode != null && statusCode >= 400 ? 'error' : 'info',
      message: 'Network request: $method $url',
      category: 'network',
      metadata: {
        'method': method,
        'url': url,
        'status_code': statusCode,
        'duration_ms': duration?.inMilliseconds,
        'request_data': requestData,
        'response_data': responseData,
      },
      sessionId: sessionId,
      userId: userId,
    );
  }

  /// Log user action
  Future<void> logUserAction({
    required String action,
    String? screen,
    Map<String, dynamic>? metadata,
    String? sessionId,
    String? userId,
  }) async {
    await logEvent(
      level: 'info',
      message: 'User action: $action',
      category: 'user_interaction',
      metadata: {
        'action': action,
        'screen': screen,
        ...?metadata,
      },
      sessionId: sessionId,
      userId: userId,
    );
  }

  /// Log screen navigation
  Future<void> logScreenNavigation({
    required String fromScreen,
    required String toScreen,
    Map<String, dynamic>? metadata,
    String? sessionId,
    String? userId,
  }) async {
    await logEvent(
      level: 'info',
      message: 'Screen navigation: $fromScreen -> $toScreen',
      category: 'navigation',
      metadata: {
        'from_screen': fromScreen,
        'to_screen': toScreen,
        ...?metadata,
      },
      sessionId: sessionId,
      userId: userId,
    );
  }

  /// Flush all pending logs immediately
  Future<void> flush() async {
    if (!_isInitialized) return;

    await _processBatch();
    dev.log('HyperDX logs flushed');
  }

  /// Get current buffer size
  int get bufferSize => _logBuffer.length;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose resources
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      // Flush remaining logs
      await _processBatch();
      
      // Cancel timer
      _batchTimer?.cancel();
      _batchTimer = null;

      // Close Dio client
      _dio?.close();
      _dio = null;

      // Close Hive box
      await _logBox?.close();
      _logBox = null;

      _isInitialized = false;
      dev.log('HyperDX logging service disposed');
    } catch (e) {
      dev.log('Error disposing HyperDX logging service: $e');
    }
  }
}
