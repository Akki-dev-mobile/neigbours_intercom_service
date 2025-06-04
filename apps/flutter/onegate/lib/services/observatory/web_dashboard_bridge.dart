import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_onegate/services/observatory/observatory_dashboard_service.dart';
import 'package:flutter_onegate/services/crash_reporting/crash_reporter_service.dart';
import 'package:flutter_onegate/services/crash_reporting/analytics_service.dart';
import 'package:flutter_onegate/services/data_health/data_health_service.dart';
import 'package:flutter_onegate/utils/network_log/services/network_log_service.dart';

/// Bridge service that sends real-time data from OneGate Flutter app
/// to the web dashboard API for live monitoring
class WebDashboardBridge {
  static final WebDashboardBridge _instance = WebDashboardBridge._internal();
  factory WebDashboardBridge() => _instance;
  WebDashboardBridge._internal();

  static const String _defaultApiUrl = 'http://localhost:8877/api';
  
  String _apiUrl = _defaultApiUrl;
  Dio? _dio;
  Timer? _dataTransmissionTimer;
  bool _isInitialized = false;
  bool _isTransmitting = false;

  // Service instances
  ObservatoryDashboardService? _observatoryService;
  CrashReporterService? _crashService;
  AnalyticsService? _analyticsService;
  DataHealthService? _healthService;
  NetworkLogService? _networkLogService;

  /// Initialize the web dashboard bridge
  Future<void> initialize({String? apiUrl}) async {
    if (_isInitialized) return;

    try {
      _apiUrl = apiUrl ?? _defaultApiUrl;
      
      // Initialize Dio client
      _dio = Dio(BaseOptions(
        baseUrl: _apiUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
        headers: {
          'Content-Type': 'application/json',
        },
      ));

      // Initialize service instances
      _observatoryService = ObservatoryDashboardService();
      _crashService = CrashReporterService();
      _analyticsService = AnalyticsService();
      _healthService = DataHealthService();
      _networkLogService = NetworkLogService();

      _isInitialized = true;
      dev.log('Web Dashboard Bridge initialized successfully');

      // Start periodic data transmission
      await startDataTransmission();

    } catch (e) {
      dev.log('Error initializing Web Dashboard Bridge: $e');
      rethrow;
    }
  }

  /// Start periodic data transmission to web dashboard
  Future<void> startDataTransmission({Duration? interval}) async {
    if (!_isInitialized || _isTransmitting) return;

    final transmissionInterval = interval ?? const Duration(seconds: 5);
    
    _dataTransmissionTimer = Timer.periodic(transmissionInterval, (_) {
      _transmitDataToWebDashboard();
    });

    _isTransmitting = true;
    dev.log('Started data transmission to web dashboard (${transmissionInterval.inSeconds}s intervals)');

    // Send initial data immediately
    await _transmitDataToWebDashboard();
  }

  /// Stop data transmission
  void stopDataTransmission() {
    _dataTransmissionTimer?.cancel();
    _dataTransmissionTimer = null;
    _isTransmitting = false;
    dev.log('Stopped data transmission to web dashboard');
  }

  /// Transmit current data to web dashboard API
  Future<void> _transmitDataToWebDashboard() async {
    if (!_isInitialized || _dio == null) return;

    try {
      final data = await _gatherCurrentData();
      
      await _dio!.post('/data', data: jsonEncode(data));
      
      dev.log('Successfully transmitted data to web dashboard');
    } catch (e) {
      dev.log('Error transmitting data to web dashboard: $e');
      // Don't rethrow - continue trying on next interval
    }
  }

  /// Gather current data from all OneGate services
  Future<Map<String, dynamic>> _gatherCurrentData() async {
    final now = DateTime.now();
    
    // Gather metrics
    final metrics = await _gatherMetrics();
    
    // Gather logs
    final logs = await _gatherLogs();
    
    // Gather system status
    final status = await _gatherSystemStatus();

    return {
      'timestamp': now.toIso8601String(),
      'metrics': metrics,
      'logs': logs,
      'status': status,
      'source': 'onegate_flutter',
    };
  }

  /// Gather metrics from various services
  Future<List<Map<String, dynamic>>> _gatherMetrics() async {
    final metrics = <Map<String, dynamic>>[];

    try {
      // Network metrics from NetworkLogService
      final networkLogs = _networkLogService?.logs.value ?? [];
      final totalRequests = networkLogs.length;
      final successfulRequests = networkLogs.where((log) => 
          log.statusCode != null && log.statusCode! >= 200 && log.statusCode! < 300).length;
      final failedRequests = networkLogs.where((log) => 
          log.statusCode != null && log.statusCode! >= 400).length;
      final avgResponseTime = networkLogs.isNotEmpty 
          ? networkLogs.map((log) => log.duration ?? 0).reduce((a, b) => a + b) / networkLogs.length
          : 0;

      metrics.addAll([
        _createMetric('network', 'network_requests_total', totalRequests),
        _createMetric('network', 'network_requests_successful', successfulRequests),
        _createMetric('network', 'network_requests_failed', failedRequests),
        _createMetric('network', 'avg_response_time', avgResponseTime.round()),
      ]);

      // Crash metrics from CrashReporterService
      final crashStats = _crashService?.getCrashStatistics() ?? {};
      metrics.addAll([
        _createMetric('crash', 'total_crashes', crashStats['totalCrashes'] ?? 0),
        _createMetric('crash', 'fatal_crashes', crashStats['fatalCrashes'] ?? 0),
        _createMetric('crash', 'handled_exceptions', crashStats['handledExceptions'] ?? 0),
      ]);

      // Analytics metrics from AnalyticsService
      final analyticsStats = _analyticsService?.getAnalyticsStatistics() ?? {};
      metrics.addAll([
        _createMetric('analytics', 'total_events', analyticsStats['totalEvents'] ?? 0),
        _createMetric('analytics', 'active_users', analyticsStats['activeUsers'] ?? 0),
        _createMetric('analytics', 'session_duration', analyticsStats['sessionDuration'] ?? '0m 0s'),
      ]);

      // App info metrics
      metrics.addAll([
        _createMetric('app', 'app_version', '1.0.0+1'),
        _createMetric('app', 'platform', 'flutter'),
        _createMetric('app', 'debug_mode', kDebugMode),
      ]);

    } catch (e) {
      dev.log('Error gathering metrics: $e');
    }

    return metrics;
  }

  /// Create a metric object
  Map<String, dynamic> _createMetric(String type, String name, dynamic value, {Map<String, dynamic>? metadata}) {
    return {
      'type': type,
      'name': name,
      'value': value,
      'timestamp': DateTime.now().toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Gather recent logs from various services
  Future<List<Map<String, dynamic>>> _gatherLogs() async {
    final logs = <Map<String, dynamic>>[];

    try {
      // Add system logs
      logs.add(_createLog('info', 'Data transmission to web dashboard active', 'web_bridge'));
      
      // Add network logs (recent ones)
      final networkLogs = _networkLogService?.logs.value ?? [];
      final recentNetworkLogs = networkLogs.take(5);
      
      for (final networkLog in recentNetworkLogs) {
        final level = (networkLog.statusCode != null && networkLog.statusCode! >= 400) ? 'error' : 'info';
        final message = 'Network request: ${networkLog.method} ${networkLog.url} - ${networkLog.statusCode ?? 'pending'}';
        logs.add(_createLog(level, message, 'network_service', {
          'url': networkLog.url,
          'method': networkLog.method,
          'statusCode': networkLog.statusCode,
          'duration': networkLog.duration,
        }));
      }

      // Add health check logs
      final healthResult = await _healthService?.getLastHealthCheckResult();
      if (healthResult != null) {
        logs.add(_createLog('info', 'Health check completed: ${healthResult.overallStatus.name}', 'health_service', {
          'overall_status': healthResult.overallStatus.name,
          'resident_data': healthResult.residentDataCheck?.status.name,
          'visitor_data': healthResult.visitorDataCheck?.status.name,
          'api_health': healthResult.apiHealthCheck?.status.name,
        }));
      }

    } catch (e) {
      dev.log('Error gathering logs: $e');
      logs.add(_createLog('error', 'Error gathering logs: $e', 'web_bridge'));
    }

    return logs;
  }

  /// Create a log object
  Map<String, dynamic> _createLog(String level, String message, String source, [Map<String, dynamic>? metadata]) {
    return {
      'level': level,
      'message': message,
      'source': source,
      'timestamp': DateTime.now().toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Gather system status from various services
  Future<List<Map<String, dynamic>>> _gatherSystemStatus() async {
    final status = <Map<String, dynamic>>[];

    try {
      // Observatory service status
      status.add(_createStatus('observatory_service', 
          _observatoryService?.isInitialized == true ? 'active' : 'inactive'));

      // Data collection status
      status.add(_createStatus('data_collection', 
          _observatoryService?.isCollectingMetrics == true ? 'running' : 'stopped'));

      // Web bridge status
      status.add(_createStatus('web_bridge', _isTransmitting ? 'active' : 'inactive'));

      // Network service status
      status.add(_createStatus('network_service', 
          _networkLogService != null ? 'active' : 'inactive'));

      // Crash service status
      status.add(_createStatus('crash_service', 
          _crashService != null ? 'active' : 'inactive'));

      // Analytics service status
      status.add(_createStatus('analytics_service', 
          _analyticsService != null ? 'active' : 'inactive'));

      // Health service status
      status.add(_createStatus('health_service', 
          _healthService != null ? 'active' : 'inactive'));

    } catch (e) {
      dev.log('Error gathering system status: $e');
      status.add(_createStatus('web_bridge', 'error', 'Error gathering status: $e'));
    }

    return status;
  }

  /// Create a status object
  Map<String, dynamic> _createStatus(String service, String status, [String? details]) {
    return {
      'service': service,
      'status': status,
      'details': details,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Send a custom metric to the web dashboard
  Future<void> sendCustomMetric(String type, String name, dynamic value, {Map<String, dynamic>? metadata}) async {
    if (!_isInitialized || _dio == null) return;

    try {
      final metric = _createMetric(type, name, value, metadata: metadata);
      
      await _dio!.post('/data', data: jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'metrics': [metric],
        'source': 'onegate_flutter_custom',
      }));

      dev.log('Custom metric sent: $type.$name = $value');
    } catch (e) {
      dev.log('Error sending custom metric: $e');
    }
  }

  /// Send a custom log to the web dashboard
  Future<void> sendCustomLog(String level, String message, {String? source, Map<String, dynamic>? metadata}) async {
    if (!_isInitialized || _dio == null) return;

    try {
      final log = _createLog(level, message, source ?? 'onegate_flutter', metadata);
      
      await _dio!.post('/data', data: jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'logs': [log],
        'source': 'onegate_flutter_custom',
      }));

      dev.log('Custom log sent: [$level] $message');
    } catch (e) {
      dev.log('Error sending custom log: $e');
    }
  }

  /// Update API URL and reinitialize connection
  Future<void> updateApiUrl(String newApiUrl) async {
    _apiUrl = newApiUrl;
    
    if (_isInitialized) {
      // Reinitialize with new URL
      _isInitialized = false;
      await initialize(apiUrl: newApiUrl);
    }
  }

  /// Get current configuration
  Map<String, dynamic> getConfiguration() {
    return {
      'api_url': _apiUrl,
      'is_initialized': _isInitialized,
      'is_transmitting': _isTransmitting,
      'transmission_interval': _dataTransmissionTimer?.isActive == true ? '5 seconds' : 'stopped',
    };
  }

  /// Check if the web dashboard API is reachable
  Future<bool> checkApiConnection() async {
    if (!_isInitialized || _dio == null) return false;

    try {
      final response = await _dio!.get('/status');
      return response.statusCode == 200;
    } catch (e) {
      dev.log('API connection check failed: $e');
      return false;
    }
  }

  /// Get current bridge status
  bool get isInitialized => _isInitialized;
  bool get isTransmitting => _isTransmitting;
  String get apiUrl => _apiUrl;

  /// Dispose resources
  Future<void> dispose() async {
    stopDataTransmission();
    _dio?.close();
    _dio = null;
    _isInitialized = false;
    dev.log('Web Dashboard Bridge disposed');
  }
}
