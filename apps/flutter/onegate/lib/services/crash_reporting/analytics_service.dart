import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_onegate/services/crash_reporting/models/crash_models.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'dart:developer' as dev;

/// Analytics service for tracking user events and app performance
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static const String _eventsBoxName = 'analytics_events';
  static const String _performanceBoxName = 'performance_metrics';
  static const int _maxEvents = 5000;

  Box<AnalyticsEvent>? _eventsBox;
  Box<Map>? _performanceBox;
  GateStorage? _gateStorage;

  String? _currentSessionId;
  DateTime? _sessionStartTime;
  DateTime? _lastEventTime;

  final Map<String, DateTime> _screenStartTimes = {};
  final Map<String, Stopwatch> _performanceTimers = {};

  bool _isInitialized = false;
  Timer? _cleanupTimer;

  /// Initialize the analytics service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Note: Hive is already initialized in main.dart
      _eventsBox = await Hive.openBox<AnalyticsEvent>(_eventsBoxName);
      _performanceBox = await Hive.openBox<Map>(_performanceBoxName);

      _gateStorage = GateStorage();
      await _gateStorage!.init();

      // Start new session
      await _startNewSession();

      // Set up periodic cleanup
      _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
        _cleanupOldEvents();
      });

      _isInitialized = true;
      dev.log('AnalyticsService initialized successfully');

      // Track initialization event
      await trackEvent('analytics_initialized', {
        'timestamp': DateTime.now().toIso8601String(),
        'platform': Platform.operatingSystem,
      });
    } catch (e) {
      dev.log('Error initializing AnalyticsService: $e');
      rethrow;
    }
  }

  /// Start a new analytics session
  Future<void> _startNewSession() async {
    try {
      _currentSessionId = const Uuid().v4();
      _sessionStartTime = DateTime.now();
      _lastEventTime = DateTime.now();

      dev.log('Started new analytics session: $_currentSessionId');

      // Track session start
      await trackEvent('session_start', {
        'session_id': _currentSessionId,
        'start_time': _sessionStartTime!.toIso8601String(),
      });
    } catch (e) {
      dev.log('Error starting new analytics session: $e');
    }
  }

  /// Track a custom event
  Future<void> trackEvent(
    String eventName,
    Map<String, dynamic> parameters, {
    EventCategory category = EventCategory.userAction,
  }) async {
    try {
      if (!_isInitialized) {
        dev.log('Analytics not initialized, queuing event: $eventName');
        return;
      }

      final userId = await _gateStorage?.getUserId();
      final selectedGate = await _gateStorage?.getSelectedGate();
      final gateId = selectedGate?['gate_id']?.toString();

      final event = AnalyticsEvent(
        id: const Uuid().v4(),
        eventName: eventName,
        parameters: parameters,
        timestamp: DateTime.now(),
        userId: userId,
        gateId: gateId,
        sessionId: _currentSessionId,
        eventCategory: category.name,
      );

      await _eventsBox!.add(event);
      _lastEventTime = DateTime.now();

      dev.log('Tracked event: $eventName');
    } catch (e) {
      dev.log('Error tracking event $eventName: $e');
    }
  }

  /// Track screen view
  Future<void> trackScreenView(String screenName,
      {Map<String, dynamic>? parameters}) async {
    final params = parameters ?? {};
    params['screen_name'] = screenName;
    params['previous_screen'] = _getLastScreen();

    await trackEvent('screen_view', params, category: EventCategory.navigation);

    // Start timing for this screen
    _screenStartTimes[screenName] = DateTime.now();
  }

  /// Track screen time when leaving a screen
  Future<void> trackScreenTime(String screenName) async {
    final startTime = _screenStartTimes[screenName];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);

      await trackEvent(
          'screen_time',
          {
            'screen_name': screenName,
            'duration_ms': duration.inMilliseconds,
            'duration_seconds': duration.inSeconds,
          },
          category: EventCategory.performance);

      _screenStartTimes.remove(screenName);
    }
  }

  /// Track user action
  Future<void> trackUserAction(
    String action,
    String element, {
    Map<String, dynamic>? additionalData,
  }) async {
    final params = <String, dynamic>{
      'action': action,
      'element': element,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (additionalData != null) {
      params.addAll(additionalData);
    }

    await trackEvent('user_action', params, category: EventCategory.userAction);
  }

  /// Track button tap
  Future<void> trackButtonTap(String buttonName, {String? screenName}) async {
    await trackUserAction('tap', buttonName, additionalData: {
      'screen_name': screenName ?? _getCurrentScreen(),
    });
  }

  /// Track form submission
  Future<void> trackFormSubmission(
    String formName,
    bool isSuccessful, {
    Map<String, dynamic>? formData,
  }) async {
    final params = {
      'form_name': formName,
      'is_successful': isSuccessful,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (formData != null) {
      params['form_data'] = formData;
    }

    await trackEvent('form_submission', params,
        category: EventCategory.userAction);
  }

  /// Track API call performance
  Future<void> trackApiCall(
    String endpoint,
    String method,
    int statusCode,
    int durationMs, {
    Map<String, dynamic>? additionalData,
  }) async {
    final params = <String, dynamic>{
      'endpoint': endpoint,
      'method': method,
      'status_code': statusCode,
      'duration_ms': durationMs,
      'is_successful': statusCode >= 200 && statusCode < 300,
    };

    if (additionalData != null) {
      params.addAll(additionalData);
    }

    await trackEvent('api_call', params, category: EventCategory.performance);
  }

  /// Start performance timer
  void startPerformanceTimer(String timerName) {
    _performanceTimers[timerName] = Stopwatch()..start();
  }

  /// Stop performance timer and track the duration
  Future<void> stopPerformanceTimer(
    String timerName, {
    Map<String, dynamic>? additionalData,
  }) async {
    final stopwatch = _performanceTimers[timerName];
    if (stopwatch != null) {
      stopwatch.stop();

      final params = <String, dynamic>{
        'timer_name': timerName,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'duration_seconds': stopwatch.elapsed.inSeconds,
      };

      if (additionalData != null) {
        params.addAll(additionalData);
      }

      await trackEvent('performance_timer', params,
          category: EventCategory.performance);

      _performanceTimers.remove(timerName);
    }
  }

  /// Track app startup time
  Future<void> trackAppStartup(Duration startupTime) async {
    await trackEvent(
        'app_startup',
        {
          'startup_time_ms': startupTime.inMilliseconds,
          'startup_time_seconds': startupTime.inSeconds,
        },
        category: EventCategory.performance);
  }

  /// Track memory usage
  Future<void> trackMemoryUsage() async {
    try {
      // This is a simplified memory tracking - in production you might want more detailed metrics
      await trackEvent(
          'memory_usage',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'platform': Platform.operatingSystem,
          },
          category: EventCategory.performance);
    } catch (e) {
      dev.log('Error tracking memory usage: $e');
    }
  }

  /// Track error event
  Future<void> trackError(
    String errorType,
    String errorMessage, {
    bool isFatal = false,
    Map<String, dynamic>? additionalData,
  }) async {
    final params = <String, dynamic>{
      'error_type': errorType,
      'error_message': errorMessage,
      'is_fatal': isFatal,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (additionalData != null) {
      params.addAll(additionalData);
    }

    await trackEvent('error_occurred', params, category: EventCategory.error);
  }

  /// Track visitor check-in/out events
  Future<void> trackVisitorEvent(
    String eventType, // 'check_in', 'check_out', 'approval_request', etc.
    String visitorId, {
    Map<String, dynamic>? visitorData,
  }) async {
    final params = <String, dynamic>{
      'event_type': eventType,
      'visitor_id': visitorId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (visitorData != null) {
      params.addAll(visitorData);
    }

    await trackEvent('visitor_event', params,
        category: EventCategory.userAction);
  }

  /// Track gate operations
  Future<void> trackGateOperation(
    String operation, // 'open', 'close', 'manual_override', etc.
    String gateId, {
    Map<String, dynamic>? operationData,
  }) async {
    final params = <String, dynamic>{
      'operation': operation,
      'gate_id': gateId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (operationData != null) {
      params.addAll(operationData);
    }

    await trackEvent('gate_operation', params, category: EventCategory.system);
  }

  /// Get all analytics events
  List<AnalyticsEvent> getAllEvents() {
    return _eventsBox?.values.toList() ?? [];
  }

  /// Get events by filter
  List<AnalyticsEvent> getEvents({
    String? eventName,
    EventCategory? category,
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
    String? sessionId,
    int? limit,
  }) {
    var events = _eventsBox?.values.toList() ?? [];

    if (eventName != null) {
      events = events.where((e) => e.eventName == eventName).toList();
    }

    if (category != null) {
      events = events.where((e) => e.eventCategory == category.name).toList();
    }

    if (startDate != null) {
      events = events.where((e) => e.timestamp.isAfter(startDate)).toList();
    }

    if (endDate != null) {
      events = events.where((e) => e.timestamp.isBefore(endDate)).toList();
    }

    if (userId != null) {
      events = events.where((e) => e.userId == userId).toList();
    }

    if (sessionId != null) {
      events = events.where((e) => e.sessionId == sessionId).toList();
    }

    // Sort by timestamp (newest first)
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (limit != null && events.length > limit) {
      events = events.take(limit).toList();
    }

    return events;
  }

  /// Get analytics statistics
  Map<String, dynamic> getAnalyticsStatistics() {
    final events = getAllEvents();
    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));
    final last7Days = now.subtract(const Duration(days: 7));

    final totalEvents = events.length;
    final events24h =
        events.where((e) => e.timestamp.isAfter(last24Hours)).length;
    final events7d = events.where((e) => e.timestamp.isAfter(last7Days)).length;

    // Group by event name
    final eventCounts = <String, int>{};
    for (final event in events) {
      eventCounts[event.eventName] = (eventCounts[event.eventName] ?? 0) + 1;
    }

    // Group by category
    final categoryCounts = <String, int>{};
    for (final event in events) {
      categoryCounts[event.eventCategory] =
          (categoryCounts[event.eventCategory] ?? 0) + 1;
    }

    // Calculate session statistics
    final uniqueSessions =
        events.map((e) => e.sessionId).where((s) => s != null).toSet().length;
    final uniqueUsers =
        events.map((e) => e.userId).where((u) => u != null).toSet().length;

    return {
      'totalEvents': totalEvents,
      'events24h': events24h,
      'events7d': events7d,
      'uniqueSessions': uniqueSessions,
      'uniqueUsers': uniqueUsers,
      'eventCounts': eventCounts,
      'categoryCounts': categoryCounts,
      'lastEventTime': events.isNotEmpty ? events.first.timestamp : null,
      'currentSessionId': _currentSessionId,
      'sessionStartTime': _sessionStartTime,
    };
  }

  /// Clean up old events
  Future<void> _cleanupOldEvents() async {
    try {
      final allEvents = _eventsBox!.values.toList();

      if (allEvents.length > _maxEvents) {
        // Sort by timestamp and keep only the most recent
        allEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        final toDelete = allEvents.skip(_maxEvents).toList();
        for (final event in toDelete) {
          await event.delete();
        }

        dev.log('Cleaned up ${toDelete.length} old analytics events');
      }
    } catch (e) {
      dev.log('Error cleaning up old events: $e');
    }
  }

  /// Get last screen from recent screen_view events
  String? _getLastScreen() {
    final screenEvents = getEvents(
      eventName: 'screen_view',
      limit: 2,
    );

    if (screenEvents.length >= 2) {
      return screenEvents[1].parameters['screen_name'] as String?;
    }

    return null;
  }

  /// Get current screen from most recent screen_view event
  String? _getCurrentScreen() {
    final screenEvents = getEvents(
      eventName: 'screen_view',
      limit: 1,
    );

    if (screenEvents.isNotEmpty) {
      return screenEvents.first.parameters['screen_name'] as String?;
    }

    return null;
  }

  /// End current session
  Future<void> endCurrentSession() async {
    try {
      if (_currentSessionId != null && _sessionStartTime != null) {
        final sessionDuration = DateTime.now().difference(_sessionStartTime!);

        await trackEvent('session_end', {
          'session_id': _currentSessionId,
          'session_duration_ms': sessionDuration.inMilliseconds,
          'session_duration_minutes': sessionDuration.inMinutes,
          'end_time': DateTime.now().toIso8601String(),
        });

        _currentSessionId = null;
        _sessionStartTime = null;
      }
    } catch (e) {
      dev.log('Error ending analytics session: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    endCurrentSession();
  }
}
