import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_onegate/services/crash_reporting/crash_reporter_service.dart';
import 'package:flutter_onegate/services/crash_reporting/analytics_service.dart';
import 'package:flutter_onegate/services/data_health/data_health_service.dart';
import 'package:flutter_onegate/utils/network_log/services/network_log_service.dart';
import 'package:flutter_onegate/services/notifications/custom_notification_service.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';

/// Enhanced Observatory Dashboard Service for OneGate
/// Integrates with OneApp Observatory & Monitoring Stack
class ObservatoryDashboardService {
  static final ObservatoryDashboardService _instance =
      ObservatoryDashboardService._internal();
  factory ObservatoryDashboardService() => _instance;
  ObservatoryDashboardService._internal();

  static const String _metricsBoxName = 'observatory_metrics';
  static const String _configBoxName = 'observatory_config';

  Box<Map>? _metricsBox;
  Box<Map>? _configBox;
  GateStorage? _gateStorage;

  // Service instances
  CrashReporterService? _crashService;
  AnalyticsService? _analyticsService;
  DataHealthService? _healthService;
  NetworkLogService? _networkLogService;
  CustomNotificationService? _notificationService;

  // WebSocket connections for real-time monitoring
  WebSocketChannel? _dashboardChannel;
  WebSocketChannel? _metricsChannel;

  // Timers for periodic data collection
  Timer? _metricsCollectionTimer;
  Timer? _healthCheckTimer;
  Timer? _performanceTimer;

  bool _isInitialized = false;
  bool _isCollectingMetrics = false;

  // Observatory configuration
  Map<String, dynamic> _observatoryConfig = {
    'dashboardUrl': 'http://localhost:5015',
    'consolidatedDashboardUrl': 'http://localhost:3002',
    'observabilityStackUrl': 'http://localhost:3000',
    'signozUrl': 'http://localhost:3301',
    'grafanaUrl': 'http://localhost:3000',
    'postHogUrl': 'http://localhost:8000',
    'sentryDsn': '',
    'hyperDxUrl': 'http://localhost:8080',
    'skyWalkingUrl': 'http://localhost:8080',
    'measureAnalyticsUrl': 'http://localhost:3000',
    'highlightUrl': 'http://localhost:4318',
    'enableRealTimeMetrics': true,
    'metricsCollectionInterval': 30, // seconds
    'healthCheckInterval': 300, // seconds (5 minutes)
    'performanceMonitoringInterval': 60, // seconds
  };

  /// Initialize the Observatory Dashboard Service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive boxes
      _metricsBox = await Hive.openBox<Map>(_metricsBoxName);
      _configBox = await Hive.openBox<Map>(_configBoxName);

      // Initialize storage
      _gateStorage = GateStorage();
      await _gateStorage!.init();

      // Initialize service instances
      _crashService = CrashReporterService();
      await _crashService!.initialize();

      _analyticsService = AnalyticsService();
      await _analyticsService!.initialize();

      _healthService = DataHealthService();
      await _healthService!.initialize();

      _networkLogService = NetworkLogService();
      await _networkLogService!.init();

      _notificationService = CustomNotificationService();
      await _notificationService!.initialize();

      // Load configuration
      await _loadConfiguration();

      // Initialize WebSocket connections if enabled
      if (_observatoryConfig['enableRealTimeMetrics'] == true) {
        await _initializeWebSocketConnections();
      }

      // Start periodic data collection
      await _startPeriodicDataCollection();

      _isInitialized = true;
      dev.log('Observatory Dashboard Service initialized successfully');

      // Track initialization
      await _analyticsService!.trackEvent('observatory_initialized', {
        'timestamp': DateTime.now().toIso8601String(),
        'config': _observatoryConfig,
      });
    } catch (e) {
      dev.log('Error initializing Observatory Dashboard Service: $e');
      rethrow;
    }
  }

  /// Load configuration from storage or use defaults
  Future<void> _loadConfiguration() async {
    try {
      final storedConfig = _configBox?.get('observatory_config');
      if (storedConfig != null) {
        _observatoryConfig = Map<String, dynamic>.from(storedConfig);
      }

      // Override with environment-specific URLs if available
      final gateId = await _gateStorage?.getSelectedGate();
      if (gateId != null) {
        // Customize URLs based on gate configuration
        await _customizeUrlsForGate(gateId);
      }
    } catch (e) {
      dev.log('Error loading observatory configuration: $e');
    }
  }

  /// Customize URLs based on gate configuration
  Future<void> _customizeUrlsForGate(Map<String, dynamic> gateConfig) async {
    try {
      // This could be enhanced to load gate-specific monitoring endpoints
      final gateId = gateConfig['gate_id']?.toString();
      if (gateId != null) {
        // Example: Use gate-specific monitoring endpoints
        _observatoryConfig['dashboardUrl'] =
            'http://localhost:5015/gate/$gateId';
      }
    } catch (e) {
      dev.log('Error customizing URLs for gate: $e');
    }
  }

  /// Initialize WebSocket connections for real-time monitoring
  Future<void> _initializeWebSocketConnections() async {
    try {
      // Connect to main dashboard
      final dashboardWsUrl =
          '${_observatoryConfig['dashboardUrl'].toString().replaceFirst('http', 'ws')}/ws';

      _dashboardChannel = WebSocketChannel.connect(Uri.parse(dashboardWsUrl));

      // Listen for dashboard messages
      _dashboardChannel!.stream.listen(
        (data) => _handleDashboardMessage(data),
        onError: (error) => dev.log('Dashboard WebSocket error: $error'),
        onDone: () => dev.log('Dashboard WebSocket connection closed'),
      );

      // Connect to metrics stream
      final metricsWsUrl =
          '${_observatoryConfig['consolidatedDashboardUrl'].toString().replaceFirst('http', 'ws')}/metrics';

      _metricsChannel = WebSocketChannel.connect(Uri.parse(metricsWsUrl));

      // Listen for metrics messages
      _metricsChannel!.stream.listen(
        (data) => _handleMetricsMessage(data),
        onError: (error) => dev.log('Metrics WebSocket error: $error'),
        onDone: () => dev.log('Metrics WebSocket connection closed'),
      );

      dev.log('WebSocket connections initialized successfully');
    } catch (e) {
      dev.log('Error initializing WebSocket connections: $e');
      // Continue without real-time features if WebSocket fails
    }
  }

  /// Handle dashboard WebSocket messages
  void _handleDashboardMessage(dynamic data) {
    try {
      final message = jsonDecode(data.toString());

      switch (message['type']) {
        case 'alert':
          _handleDashboardAlert(message);
          break;
        case 'metric_update':
          _handleMetricUpdate(message);
          break;
        case 'health_status':
          _handleHealthStatusUpdate(message);
          break;
        default:
          dev.log('Unknown dashboard message type: ${message['type']}');
      }
    } catch (e) {
      dev.log('Error handling dashboard message: $e');
    }
  }

  /// Handle metrics WebSocket messages
  void _handleMetricsMessage(dynamic data) {
    try {
      final metrics = jsonDecode(data.toString());

      // Store real-time metrics
      _storeRealTimeMetrics(metrics);

      // Update analytics
      _analyticsService?.trackEvent('real_time_metrics_received', {
        'timestamp': DateTime.now().toIso8601String(),
        'metrics_count': metrics.length,
      });
    } catch (e) {
      dev.log('Error handling metrics message: $e');
    }
  }

  /// Start periodic data collection
  Future<void> _startPeriodicDataCollection() async {
    if (!kDebugMode) {
      dev.log('Observatory data collection disabled in release mode');
      return;
    }

    try {
      // Metrics collection timer
      final metricsInterval = Duration(
        seconds: _observatoryConfig['metricsCollectionInterval'] ?? 30,
      );

      _metricsCollectionTimer = Timer.periodic(metricsInterval, (_) {
        _collectAndSendMetrics();
      });

      // Health check timer
      final healthInterval = Duration(
        seconds: _observatoryConfig['healthCheckInterval'] ?? 300,
      );

      _healthCheckTimer = Timer.periodic(healthInterval, (_) {
        _performHealthCheck();
      });

      // Performance monitoring timer
      final performanceInterval = Duration(
        seconds: _observatoryConfig['performanceMonitoringInterval'] ?? 60,
      );

      _performanceTimer = Timer.periodic(performanceInterval, (_) {
        _collectPerformanceMetrics();
      });

      _isCollectingMetrics = true;
      dev.log('Periodic data collection started');
    } catch (e) {
      dev.log('Error starting periodic data collection: $e');
    }
  }

  /// Collect and send metrics to observatory
  Future<void> _collectAndSendMetrics() async {
    if (!_isCollectingMetrics) return;

    try {
      final metrics = await _gatherAllMetrics();

      // Store locally
      await _storeMetrics(metrics);

      // Send to observatory dashboard
      await _sendMetricsToObservatory(metrics);

      // Send to individual monitoring platforms
      await _sendToMonitoringPlatforms(metrics);
    } catch (e) {
      dev.log('Error collecting and sending metrics: $e');
    }
  }

  /// Gather all metrics from various services
  Future<Map<String, dynamic>> _gatherAllMetrics() async {
    final metrics = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'app_info': await _getAppInfo(),
      'crash_metrics': _getCrashMetrics(),
      'analytics_metrics': _getAnalyticsMetrics(),
      'network_metrics': _getNetworkMetrics(),
      'health_metrics': await _getHealthMetrics(),
      'performance_metrics': await _getPerformanceMetrics(),
    };

    return metrics;
  }

  /// Get application information
  Future<Map<String, dynamic>> _getAppInfo() async {
    final gateInfo = await _gateStorage?.getSelectedGate();

    return {
      'app_name': 'OneGate',
      'version': '1.0.0+1',
      'platform': 'Flutter',
      'gate_id': gateInfo?['gate_id'],
      'user_id': await _gateStorage?.getUserId(),
      'device_id': 'device_${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  /// Get crash metrics
  Map<String, dynamic> _getCrashMetrics() {
    return _crashService?.getCrashStatistics() ?? {};
  }

  /// Get analytics metrics
  Map<String, dynamic> _getAnalyticsMetrics() {
    return _analyticsService?.getAnalyticsStatistics() ?? {};
  }

  /// Get network metrics
  Map<String, dynamic> _getNetworkMetrics() {
    final logs = _networkLogService?.logs.value ?? [];

    return {
      'total_requests': logs.length,
      'successful_requests': logs
          .where((log) =>
              log.statusCode != null &&
              log.statusCode! >= 200 &&
              log.statusCode! < 300)
          .length,
      'failed_requests': logs
          .where((log) => log.statusCode != null && log.statusCode! >= 400)
          .length,
      'average_response_time': logs.isNotEmpty
          ? logs.map((log) => log.duration ?? 0).reduce((a, b) => a + b) /
              logs.length
          : 0,
    };
  }

  /// Get health metrics
  Future<Map<String, dynamic>> _getHealthMetrics() async {
    final healthResult = await _healthService?.getLastHealthCheckResult();

    return {
      'overall_status': healthResult?.overallStatus.name ?? 'unknown',
      'resident_data_status':
          healthResult?.residentDataCheck?.status.name ?? 'unknown',
      'visitor_data_status':
          healthResult?.visitorDataCheck?.status.name ?? 'unknown',
      'api_health_status':
          healthResult?.apiHealthCheck?.status.name ?? 'unknown',
      'meilisearch_status':
          healthResult?.meilisearchHealthCheck?.status.name ?? 'unknown',
    };
  }

  /// Get performance metrics
  Future<Map<String, dynamic>> _getPerformanceMetrics() async {
    // This would be enhanced with actual Flutter performance monitoring
    return {
      'memory_usage': 0, // Would implement actual memory monitoring
      'cpu_usage': 0, // Would implement actual CPU monitoring
      'frame_rate': 60, // Would implement actual frame rate monitoring
      'app_start_time': 0, // Would implement actual app start time monitoring
    };
  }

  /// Store metrics locally
  Future<void> _storeMetrics(Map<String, dynamic> metrics) async {
    try {
      final key = 'metrics_${DateTime.now().millisecondsSinceEpoch}';
      await _metricsBox?.put(key, metrics);

      // Clean up old metrics (keep last 1000 entries)
      final allKeys = _metricsBox?.keys.toList() ?? [];
      if (allKeys.length > 1000) {
        final keysToDelete = allKeys.take(allKeys.length - 1000);
        for (final key in keysToDelete) {
          await _metricsBox?.delete(key);
        }
      }
    } catch (e) {
      dev.log('Error storing metrics: $e');
    }
  }

  /// Send metrics to observatory dashboard
  Future<void> _sendMetricsToObservatory(Map<String, dynamic> metrics) async {
    try {
      final dio = Dio();

      // Send to main observatory dashboard
      await dio.post(
        '${_observatoryConfig['dashboardUrl']}/api/metrics',
        data: metrics,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      // Send via WebSocket if connected
      if (_dashboardChannel != null) {
        _dashboardChannel!.sink.add(jsonEncode({
          'type': 'metrics',
          'data': metrics,
        }));
      }
    } catch (e) {
      dev.log('Error sending metrics to observatory: $e');
    }
  }

  /// Send metrics to individual monitoring platforms
  Future<void> _sendToMonitoringPlatforms(Map<String, dynamic> metrics) async {
    // Send to SigNoz APM
    await _sendToSigNoz(metrics);

    // Send to PostHog Analytics
    await _sendToPostHog(metrics);

    // Send to Grafana (via Prometheus format)
    await _sendToGrafana(metrics);

    // Send to HyperDX Logs
    await _sendToHyperDX(metrics);

    // Send to SkyWalking Tracing
    await _sendToSkyWalking(metrics);
  }

  /// Send metrics to SigNoz APM
  Future<void> _sendToSigNoz(Map<String, dynamic> metrics) async {
    try {
      final dio = Dio();
      await dio.post(
        '${_observatoryConfig['signozUrl']}/api/v1/traces',
        data: _formatForSigNoz(metrics),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      dev.log('Error sending to SigNoz: $e');
    }
  }

  /// Send metrics to PostHog Analytics
  Future<void> _sendToPostHog(Map<String, dynamic> metrics) async {
    try {
      final dio = Dio();
      await dio.post(
        '${_observatoryConfig['postHogUrl']}/capture/',
        data: _formatForPostHog(metrics),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      dev.log('Error sending to PostHog: $e');
    }
  }

  /// Send metrics to Grafana
  Future<void> _sendToGrafana(Map<String, dynamic> metrics) async {
    try {
      final dio = Dio();
      await dio.post(
        '${_observatoryConfig['grafanaUrl']}/api/v1/push',
        data: _formatForGrafana(metrics),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      dev.log('Error sending to Grafana: $e');
    }
  }

  /// Send metrics to HyperDX
  Future<void> _sendToHyperDX(Map<String, dynamic> metrics) async {
    try {
      final dio = Dio();
      await dio.post(
        '${_observatoryConfig['hyperDxUrl']}/api/logs',
        data: _formatForHyperDX(metrics),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      dev.log('Error sending to HyperDX: $e');
    }
  }

  /// Send metrics to SkyWalking
  Future<void> _sendToSkyWalking(Map<String, dynamic> metrics) async {
    try {
      final dio = Dio();
      await dio.post(
        '${_observatoryConfig['skyWalkingUrl']}/v3/trace',
        data: _formatForSkyWalking(metrics),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      dev.log('Error sending to SkyWalking: $e');
    }
  }

  // Format methods for different platforms
  Map<String, dynamic> _formatForSigNoz(Map<String, dynamic> metrics) {
    return {
      'resourceSpans': [
        {
          'resource': {
            'attributes': [
              {
                'key': 'service.name',
                'value': {'stringValue': 'onegate-flutter'}
              },
              {
                'key': 'service.version',
                'value': {'stringValue': '1.0.0'}
              },
            ],
          },
          'instrumentationLibrarySpans': [
            {
              'spans': [
                {
                  'traceId': _generateTraceId(),
                  'spanId': _generateSpanId(),
                  'name': 'onegate_metrics',
                  'startTimeUnixNano':
                      DateTime.now().microsecondsSinceEpoch * 1000,
                  'endTimeUnixNano':
                      DateTime.now().microsecondsSinceEpoch * 1000,
                  'attributes': _convertToAttributes(metrics),
                }
              ],
            }
          ],
        }
      ],
    };
  }

  Map<String, dynamic> _formatForPostHog(Map<String, dynamic> metrics) {
    return {
      'api_key': 'your-posthog-api-key', // Would be configured
      'event': 'onegate_metrics',
      'properties': metrics,
      'timestamp': DateTime.now().toIso8601String(),
      'distinct_id': metrics['app_info']?['user_id'] ?? 'anonymous',
    };
  }

  String _formatForGrafana(Map<String, dynamic> metrics) {
    // Convert to Prometheus format
    final lines = <String>[];
    _flattenMetrics(metrics, '', lines);
    return lines.join('\n');
  }

  Map<String, dynamic> _formatForHyperDX(Map<String, dynamic> metrics) {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'level': 'info',
      'message': 'OneGate metrics',
      'service': 'onegate-flutter',
      'attributes': metrics,
    };
  }

  Map<String, dynamic> _formatForSkyWalking(Map<String, dynamic> metrics) {
    return {
      'service': 'onegate-flutter',
      'serviceInstance': 'onegate-instance-1',
      'endpoint': 'metrics-collection',
      'traceId': _generateTraceId(),
      'traceSegmentId': _generateSpanId(),
      'spans': [
        {
          'spanId': 1,
          'parentSpanId': 0,
          'startTime': DateTime.now().millisecondsSinceEpoch,
          'endTime': DateTime.now().millisecondsSinceEpoch,
          'operationName': 'collect_metrics',
          'tags': _convertToTags(metrics),
        }
      ],
    };
  }

  // Helper methods
  String _generateTraceId() {
    return DateTime.now()
        .millisecondsSinceEpoch
        .toRadixString(16)
        .padLeft(32, '0');
  }

  String _generateSpanId() {
    return DateTime.now()
        .microsecondsSinceEpoch
        .toRadixString(16)
        .padLeft(16, '0');
  }

  List<Map<String, dynamic>> _convertToAttributes(Map<String, dynamic> data) {
    final attributes = <Map<String, dynamic>>[];

    void addAttribute(String key, dynamic value) {
      if (value is String) {
        attributes.add({
          'key': key,
          'value': {'stringValue': value}
        });
      } else if (value is num) {
        attributes.add({
          'key': key,
          'value': {'doubleValue': value.toDouble()}
        });
      } else if (value is bool) {
        attributes.add({
          'key': key,
          'value': {'boolValue': value}
        });
      }
    }

    _flattenMap(data, '', addAttribute);
    return attributes;
  }

  List<Map<String, dynamic>> _convertToTags(Map<String, dynamic> data) {
    final tags = <Map<String, dynamic>>[];

    void addTag(String key, dynamic value) {
      tags.add({'key': key, 'value': value.toString()});
    }

    _flattenMap(data, '', addTag);
    return tags;
  }

  void _flattenMap(Map<String, dynamic> map, String prefix,
      Function(String, dynamic) callback) {
    map.forEach((key, value) {
      final fullKey = prefix.isEmpty ? key : '${prefix}_$key';

      if (value is Map<String, dynamic>) {
        _flattenMap(value, fullKey, callback);
      } else {
        callback(fullKey, value);
      }
    });
  }

  void _flattenMetrics(
      Map<String, dynamic> map, String prefix, List<String> lines) {
    map.forEach((key, value) {
      final fullKey = prefix.isEmpty ? key : '${prefix}_$key';

      if (value is Map<String, dynamic>) {
        _flattenMetrics(value, fullKey, lines);
      } else if (value is num) {
        lines.add(
            'onegate_$fullKey $value ${DateTime.now().millisecondsSinceEpoch}');
      }
    });
  }

  /// Store real-time metrics
  void _storeRealTimeMetrics(Map<String, dynamic> metrics) {
    try {
      final key = 'realtime_${DateTime.now().millisecondsSinceEpoch}';
      _metricsBox?.put(key, metrics);
    } catch (e) {
      dev.log('Error storing real-time metrics: $e');
    }
  }

  /// Handle dashboard alerts
  void _handleDashboardAlert(Map<String, dynamic> alert) {
    try {
      _notificationService?.sendHealthCheckAlert(
        title: alert['title'] ?? 'Observatory Alert',
        message: alert['message'] ?? 'Alert from monitoring dashboard',
        data: alert,
      );
    } catch (e) {
      dev.log('Error handling dashboard alert: $e');
    }
  }

  /// Handle metric updates
  void _handleMetricUpdate(Map<String, dynamic> update) {
    try {
      _storeRealTimeMetrics(update);
    } catch (e) {
      dev.log('Error handling metric update: $e');
    }
  }

  /// Handle health status updates
  void _handleHealthStatusUpdate(Map<String, dynamic> status) {
    try {
      _analyticsService?.trackEvent('health_status_update', status);
    } catch (e) {
      dev.log('Error handling health status update: $e');
    }
  }

  /// Perform health check
  Future<void> _performHealthCheck() async {
    try {
      final result = await _healthService?.performHealthCheck();
      if (result != null) {
        await _sendMetricsToObservatory({
          'type': 'health_check',
          'timestamp': DateTime.now().toIso8601String(),
          'result': result.toJson(),
        });
      }
    } catch (e) {
      dev.log('Error performing health check: $e');
    }
  }

  /// Collect performance metrics
  Future<void> _collectPerformanceMetrics() async {
    try {
      final performanceMetrics = await _getPerformanceMetrics();
      await _sendMetricsToObservatory({
        'type': 'performance',
        'timestamp': DateTime.now().toIso8601String(),
        'metrics': performanceMetrics,
      });
    } catch (e) {
      dev.log('Error collecting performance metrics: $e');
    }
  }

  /// Get all stored metrics
  List<Map<String, dynamic>> getAllMetrics() {
    return _metricsBox?.values.cast<Map<String, dynamic>>().toList() ?? [];
  }

  /// Get real-time metrics
  List<Map<String, dynamic>> getRealTimeMetrics() {
    final allMetrics = getAllMetrics();
    final now = DateTime.now();
    final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

    return allMetrics.where((metric) {
      final timestamp =
          DateTime.tryParse(metric['timestamp']?.toString() ?? '');
      return timestamp != null && timestamp.isAfter(fiveMinutesAgo);
    }).toList();
  }

  /// Update configuration
  Future<void> updateConfiguration(Map<String, dynamic> newConfig) async {
    try {
      // Filter out null values to maintain configuration integrity
      final filteredConfig = Map<String, dynamic>.from(newConfig);
      filteredConfig.removeWhere((key, value) => value == null);

      _observatoryConfig.addAll(filteredConfig);
      await _configBox?.put('observatory_config', _observatoryConfig);

      // Restart services if needed
      if (_isInitialized) {
        await _restartServices();
      }
    } catch (e) {
      dev.log('Error updating configuration: $e');
    }
  }

  /// Restart services with new configuration
  Future<void> _restartServices() async {
    try {
      // Stop current services
      await dispose();

      // Reinitialize with new configuration
      await initialize();
    } catch (e) {
      dev.log('Error restarting services: $e');
    }
  }

  /// Get current configuration
  Map<String, dynamic> getConfiguration() {
    return Map<String, dynamic>.from(_observatoryConfig);
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Check if metrics collection is active
  bool get isCollectingMetrics => _isCollectingMetrics;

  /// Dispose resources
  Future<void> dispose() async {
    try {
      _isCollectingMetrics = false;

      // Cancel timers
      _metricsCollectionTimer?.cancel();
      _healthCheckTimer?.cancel();
      _performanceTimer?.cancel();

      // Close WebSocket connections
      await _dashboardChannel?.sink.close();
      await _metricsChannel?.sink.close();

      // Close Hive boxes
      await _metricsBox?.close();
      await _configBox?.close();

      _isInitialized = false;
      dev.log('Observatory Dashboard Service disposed');
    } catch (e) {
      dev.log('Error disposing Observatory Dashboard Service: $e');
    }
  }
}
