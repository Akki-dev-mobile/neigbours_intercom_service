import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Highlight session replay and user experience monitoring service
class HighlightSessionService {
  static HighlightSessionService? _instance;
  static HighlightSessionService get instance => _instance ??= HighlightSessionService._();
  
  HighlightSessionService._();

  bool _isInitialized = false;
  Dio? _dio;
  String? _endpoint;
  String? _projectId;
  String? _sessionId;
  Timer? _sessionTimer;
  Box<Map>? _sessionBox;
  final Uuid _uuid = const Uuid();
  final List<Map<String, dynamic>> _sessionEvents = [];
  final Duration _sessionTimeout = const Duration(minutes: 30);
  DateTime? _lastActivity;

  /// Initialize Highlight session service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load environment variables
      await dotenv.load(fileName: ".env");
      
      _endpoint = dotenv.env['HIGHLIGHT_ENDPOINT'] ?? 'http://localhost:4318';
      _projectId = dotenv.env['HIGHLIGHT_PROJECT_ID'] ?? 'onegate-flutter';

      // Initialize Hive storage for session data
      _sessionBox = await Hive.openBox<Map>('highlight_sessions');

      // Initialize Dio client
      _dio = Dio(BaseOptions(
        baseUrl: _endpoint!,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
        },
      ));

      // Start new session
      await _startNewSession();

      // Start session monitoring
      _startSessionMonitoring();

      _isInitialized = true;
      dev.log('Highlight session service initialized successfully');

      // Track initialization event
      await trackEvent(
        type: 'system',
        name: 'service_initialized',
        properties: {
          'service': 'highlight_session',
          'endpoint': _endpoint,
          'project_id': _projectId,
        },
      );

    } catch (e, stackTrace) {
      dev.log('Error initializing Highlight session service: $e');
      dev.log('Stack trace: $stackTrace');
    }
  }

  /// Start a new session
  Future<void> _startNewSession() async {
    _sessionId = _uuid.v4();
    _lastActivity = DateTime.now();
    _sessionEvents.clear();

    dev.log('Started new Highlight session: $_sessionId');

    // Send session start event
    await _sendSessionEvent({
      'type': 'session_start',
      'session_id': _sessionId,
      'timestamp': DateTime.now().toIso8601String(),
      'platform': defaultTargetPlatform.name,
      'project_id': _projectId,
    });
  }

  /// Start session monitoring timer
  void _startSessionMonitoring() {
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkSessionTimeout();
    });
  }

  /// Check if session has timed out
  void _checkSessionTimeout() {
    if (_lastActivity == null) return;

    final timeSinceLastActivity = DateTime.now().difference(_lastActivity!);
    if (timeSinceLastActivity > _sessionTimeout) {
      _endCurrentSession();
      _startNewSession();
    }
  }

  /// End current session
  Future<void> _endCurrentSession() async {
    if (_sessionId == null) return;

    await _sendSessionEvent({
      'type': 'session_end',
      'session_id': _sessionId,
      'timestamp': DateTime.now().toIso8601String(),
      'duration': _lastActivity != null 
          ? DateTime.now().difference(_lastActivity!).inSeconds 
          : 0,
      'events_count': _sessionEvents.length,
    });

    // Store session data locally
    await _storeSessionData();

    dev.log('Ended Highlight session: $_sessionId');
  }

  /// Send session event to Highlight
  Future<void> _sendSessionEvent(Map<String, dynamic> event) async {
    if (_dio == null) return;

    try {
      await _dio!.post('/api/sessions', data: jsonEncode(event));
      dev.log('Session event sent to Highlight: ${event['type']}');
    } catch (e) {
      dev.log('Error sending session event to Highlight: $e');
      // Store for retry
      await _storeEventForRetry(event);
    }
  }

  /// Store session data locally
  Future<void> _storeSessionData() async {
    if (_sessionBox == null || _sessionId == null) return;

    try {
      await _sessionBox!.put(_sessionId!, {
        'session_id': _sessionId,
        'events': _sessionEvents,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      dev.log('Error storing session data: $e');
    }
  }

  /// Store event for retry
  Future<void> _storeEventForRetry(Map<String, dynamic> event) async {
    if (_sessionBox == null) return;

    try {
      final retryKey = 'retry_${DateTime.now().millisecondsSinceEpoch}';
      await _sessionBox!.put(retryKey, event);
    } catch (e) {
      dev.log('Error storing event for retry: $e');
    }
  }

  /// Track a custom event
  Future<void> trackEvent({
    required String type,
    required String name,
    Map<String, dynamic>? properties,
    String? userId,
  }) async {
    if (!_isInitialized || _sessionId == null) return;

    _lastActivity = DateTime.now();

    final event = {
      'type': type,
      'name': name,
      'session_id': _sessionId,
      'timestamp': DateTime.now().toIso8601String(),
      'user_id': userId,
      'properties': properties ?? {},
      'platform': defaultTargetPlatform.name,
    };

    _sessionEvents.add(event);
    await _sendSessionEvent(event);
  }

  /// Track screen view
  Future<void> trackScreenView({
    required String screenName,
    String? previousScreen,
    Map<String, dynamic>? properties,
    String? userId,
  }) async {
    await trackEvent(
      type: 'navigation',
      name: 'screen_view',
      properties: {
        'screen_name': screenName,
        'previous_screen': previousScreen,
        ...?properties,
      },
      userId: userId,
    );
  }

  /// Track user interaction
  Future<void> trackUserInteraction({
    required String action,
    required String element,
    String? screen,
    Map<String, dynamic>? properties,
    String? userId,
  }) async {
    await trackEvent(
      type: 'interaction',
      name: action,
      properties: {
        'element': element,
        'screen': screen,
        'action': action,
        ...?properties,
      },
      userId: userId,
    );
  }

  /// Track error
  Future<void> trackError({
    required String error,
    String? stackTrace,
    String? screen,
    Map<String, dynamic>? properties,
    String? userId,
  }) async {
    await trackEvent(
      type: 'error',
      name: 'application_error',
      properties: {
        'error_message': error,
        'stack_trace': stackTrace,
        'screen': screen,
        ...?properties,
      },
      userId: userId,
    );
  }

  /// Track performance metric
  Future<void> trackPerformance({
    required String metric,
    required num value,
    String? unit,
    String? screen,
    Map<String, dynamic>? properties,
    String? userId,
  }) async {
    await trackEvent(
      type: 'performance',
      name: metric,
      properties: {
        'value': value,
        'unit': unit ?? 'ms',
        'screen': screen,
        ...?properties,
      },
      userId: userId,
    );
  }

  /// Track network request
  Future<void> trackNetworkRequest({
    required String method,
    required String url,
    int? statusCode,
    Duration? duration,
    Map<String, dynamic>? properties,
    String? userId,
  }) async {
    await trackEvent(
      type: 'network',
      name: 'http_request',
      properties: {
        'method': method,
        'url': url,
        'status_code': statusCode,
        'duration_ms': duration?.inMilliseconds,
        ...?properties,
      },
      userId: userId,
    );
  }

  /// Set user context
  Future<void> setUser({
    required String userId,
    String? email,
    String? name,
    Map<String, dynamic>? properties,
  }) async {
    await trackEvent(
      type: 'user',
      name: 'user_identified',
      properties: {
        'user_id': userId,
        'email': email,
        'name': name,
        ...?properties,
      },
      userId: userId,
    );
  }

  /// Start recording a user flow
  Future<String> startUserFlow({
    required String flowName,
    Map<String, dynamic>? properties,
    String? userId,
  }) async {
    final flowId = _uuid.v4();
    
    await trackEvent(
      type: 'flow',
      name: 'flow_start',
      properties: {
        'flow_id': flowId,
        'flow_name': flowName,
        ...?properties,
      },
      userId: userId,
    );

    return flowId;
  }

  /// End recording a user flow
  Future<void> endUserFlow({
    required String flowId,
    required String flowName,
    bool success = true,
    Map<String, dynamic>? properties,
    String? userId,
  }) async {
    await trackEvent(
      type: 'flow',
      name: 'flow_end',
      properties: {
        'flow_id': flowId,
        'flow_name': flowName,
        'success': success,
        ...?properties,
      },
      userId: userId,
    );
  }

  /// Get current session ID
  String? get currentSessionId => _sessionId;

  /// Get session events count
  int get sessionEventsCount => _sessionEvents.length;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Flush all pending events
  Future<void> flush() async {
    if (!_isInitialized) return;

    // Send any remaining events
    for (final event in _sessionEvents) {
      await _sendSessionEvent(event);
    }

    dev.log('Highlight session events flushed');
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      // End current session
      await _endCurrentSession();

      // Cancel timer
      _sessionTimer?.cancel();
      _sessionTimer = null;

      // Close Dio client
      _dio?.close();
      _dio = null;

      // Close Hive box
      await _sessionBox?.close();
      _sessionBox = null;

      _isInitialized = false;
      dev.log('Highlight session service disposed');
    } catch (e) {
      dev.log('Error disposing Highlight session service: $e');
    }
  }
}
