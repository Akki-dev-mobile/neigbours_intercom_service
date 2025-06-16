import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_onegate/services/crash_reporting/models/crash_models.dart';
import 'package:flutter_onegate/services/notifications/custom_notification_service.dart';
import 'package:flutter_onegate/services/notifications/models/notification_models.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/services/error_tracking/posthog_error_tracking_service.dart';
import 'dart:developer' as dev;

/// Comprehensive crash reporting service for OneGate app
class CrashReporterService {
  static final CrashReporterService _instance =
      CrashReporterService._internal();
  factory CrashReporterService() => _instance;
  CrashReporterService._internal();

  static const String _crashBoxName = 'crash_reports';
  static const String _sessionBoxName = 'user_sessions';
  static const int _maxCrashReports = 1000;

  Box<CrashReport>? _crashBox;
  Box<UserSession>? _sessionBox;
  GateStorage? _gateStorage;
  CustomNotificationService? _notificationService;

  String? _currentSessionId;
  String? _deviceId;
  String? _appVersion;
  String? _buildNumber;
  String? _platform;
  String? _osVersion;
  String? _deviceModel;

  final Map<String, dynamic> _customKeys = {};
  final List<Map<String, dynamic>> _breadcrumbs = [];
  final Map<String, String> _crashGroups = {}; // Error signature -> Group ID

  bool _isInitialized = false;
  Timer? _sessionTimer;

  /// Initialize the crash reporter service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Note: Hive is already initialized in main.dart
      _crashBox = await Hive.openBox<CrashReport>(_crashBoxName);
      _sessionBox = await Hive.openBox<UserSession>(_sessionBoxName);

      _gateStorage = GateStorage();
      await _gateStorage!.init();

      _notificationService = CustomNotificationService();
      await _notificationService!.initialize();

      // Collect device and app information
      await _collectDeviceInfo();
      await _collectAppInfo();

      // Start new session
      await _startNewSession();

      // Set up global error handlers
      _setupErrorHandlers();

      // Clean up old crash reports
      await _cleanupOldReports();

      _isInitialized = true;
      dev.log('CrashReporterService initialized successfully');

      // Send initialization event
      await _sendCrashNotification(
        'Crash Reporter Initialized',
        'Crash reporting service started successfully',
        AlertPriority.low,
      );
    } catch (e) {
      dev.log('Error initializing CrashReporterService: $e');
      rethrow;
    }
  }

  /// Set up global error handlers
  void _setupErrorHandlers() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };

    // Handle platform/Dart errors
    PlatformDispatcher.instance.onError = (error, stack) {
      _handlePlatformError(error, stack);
      return true;
    };

    // Handle isolate errors
    Isolate.current.addErrorListener(RawReceivePort((pair) async {
      final List<dynamic> errorAndStacktrace = pair;
      await _handleIsolateError(
        errorAndStacktrace.first,
        errorAndStacktrace.last,
      );
    }).sendPort);
  }

  /// Handle Flutter framework errors
  Future<void> _handleFlutterError(FlutterErrorDetails details) async {
    try {
      final crashReport = await _createCrashReport(
        errorMessage: details.exception.toString(),
        stackTrace: details.stack?.toString() ?? 'No stack trace available',
        errorType: 'FlutterError',
        isFatal: false,
      );

      await _saveCrashReport(crashReport);
      await _sendCrashAlert(crashReport);

      // Send to PostHog Error Tracking
      await PostHogErrorTrackingService.instance.captureFlutterError(details);

      // Also report to Flutter's default error handler in debug mode
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    } catch (e) {
      dev.log('Error handling Flutter error: $e');
    }
  }

  /// Handle platform/Dart errors
  Future<void> _handlePlatformError(Object error, StackTrace stack) async {
    try {
      final crashReport = await _createCrashReport(
        errorMessage: error.toString(),
        stackTrace: stack.toString(),
        errorType: 'PlatformError',
        isFatal: true,
      );

      await _saveCrashReport(crashReport);
      await _sendCrashAlert(crashReport);

      // Send to PostHog Error Tracking
      await PostHogErrorTrackingService.instance
          .capturePlatformError(error, stack);
    } catch (e) {
      dev.log('Error handling platform error: $e');
    }
  }

  /// Handle isolate errors
  Future<void> _handleIsolateError(dynamic error, dynamic stackTrace) async {
    try {
      final crashReport = await _createCrashReport(
        errorMessage: error.toString(),
        stackTrace: stackTrace?.toString() ?? 'No stack trace available',
        errorType: 'IsolateError',
        isFatal: true,
      );

      await _saveCrashReport(crashReport);
      await _sendCrashAlert(crashReport);
    } catch (e) {
      dev.log('Error handling isolate error: $e');
    }
  }

  /// Record a non-fatal error manually
  Future<void> recordError(
    dynamic error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? customKeys,
    bool isFatal = false,
  }) async {
    try {
      final crashReport = await _createCrashReport(
        errorMessage: error.toString(),
        stackTrace: stackTrace?.toString() ?? 'No stack trace available',
        errorType: 'ManualError',
        isFatal: isFatal,
        additionalCustomKeys: customKeys,
      );

      await _saveCrashReport(crashReport);

      // Send to PostHog Error Tracking
      await PostHogErrorTrackingService.instance.captureError(
        error: error,
        stackTrace: stackTrace,
        context: 'manual_error',
        additionalProperties: customKeys,
        isFatal: isFatal,
        errorType: 'ManualError',
      );

      if (isFatal) {
        await _sendCrashAlert(crashReport);
      }
    } catch (e) {
      dev.log('Error recording manual error: $e');
    }
  }

  /// Create a crash report
  Future<CrashReport> _createCrashReport({
    required String errorMessage,
    required String stackTrace,
    required String errorType,
    required bool isFatal,
    Map<String, dynamic>? additionalCustomKeys,
  }) async {
    final id = const Uuid().v4();
    final timestamp = DateTime.now();

    // Combine custom keys
    final allCustomKeys = Map<String, dynamic>.from(_customKeys);
    if (additionalCustomKeys != null) {
      allCustomKeys.addAll(additionalCustomKeys);
    }

    // Get user and gate info
    final userId = await _gateStorage?.getUserId();
    final selectedGate = await _gateStorage?.getSelectedGate();
    final gateId = selectedGate?['gate_id']?.toString();

    // Create breadcrumbs map
    final breadcrumbsMap = <String, dynamic>{
      'breadcrumbs': _breadcrumbs.take(10).toList(), // Keep last 10 breadcrumbs
      'timestamp': timestamp.toIso8601String(),
    };

    final crashReport = CrashReport(
      id: id,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      timestamp: timestamp,
      appVersion: _appVersion ?? 'Unknown',
      buildNumber: _buildNumber ?? 'Unknown',
      platform: _platform ?? 'Unknown',
      osVersion: _osVersion ?? 'Unknown',
      deviceModel: _deviceModel ?? 'Unknown',
      deviceId: _deviceId ?? 'Unknown',
      isFatal: isFatal,
      customKeys: allCustomKeys,
      userId: userId,
      gateId: gateId,
      sessionId: _currentSessionId,
      errorType: errorType,
      breadcrumbs: breadcrumbsMap,
    );

    // Generate and set error signature
    final signature = crashReport.generateErrorSignature();
    return crashReport.copyWith(errorSignature: signature);
  }

  /// Save crash report to local storage
  Future<void> _saveCrashReport(CrashReport crashReport) async {
    try {
      // Check if this crash already exists (deduplication)
      final existingCrash = await _findSimilarCrash(crashReport);

      if (existingCrash != null) {
        // Update existing crash count
        await existingCrash.save();
        dev.log('Updated existing crash report: ${crashReport.errorSignature}');
      } else {
        // Save new crash report
        await _crashBox!.add(crashReport);
        dev.log('Saved new crash report: ${crashReport.id}');
      }

      // Update session crash count
      await _updateSessionCrashCount();
    } catch (e) {
      dev.log('Error saving crash report: $e');
    }
  }

  /// Find similar crash for deduplication
  Future<CrashReport?> _findSimilarCrash(CrashReport newCrash) async {
    try {
      final signature =
          newCrash.errorSignature ?? newCrash.generateErrorSignature();

      // Look for crashes with same signature in last 24 hours
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));

      for (final crash in _crashBox!.values) {
        if (crash.errorSignature == signature &&
            crash.timestamp.isAfter(oneDayAgo)) {
          return crash;
        }
      }

      return null;
    } catch (e) {
      dev.log('Error finding similar crash: $e');
      return null;
    }
  }

  /// Send crash alert notification
  Future<void> _sendCrashAlert(CrashReport crashReport) async {
    try {
      final priority =
          crashReport.isFatal ? AlertPriority.max : AlertPriority.high;
      final title =
          crashReport.isFatal ? 'Fatal Crash Detected' : 'Error Detected';

      await _sendCrashNotification(
        title,
        'Error: ${crashReport.errorMessage.length > 100 ? '${crashReport.errorMessage.substring(0, 100)}...' : crashReport.errorMessage}',
        priority,
        data: {
          'crashId': crashReport.id,
          'errorType': crashReport.errorType,
          'isFatal': crashReport.isFatal,
          'timestamp': crashReport.timestamp.toIso8601String(),
          'userId': crashReport.userId,
          'gateId': crashReport.gateId,
        },
      );
    } catch (e) {
      dev.log('Error sending crash alert: $e');
    }
  }

  /// Send crash notification using custom notification service
  Future<void> _sendCrashNotification(
    String title,
    String message,
    AlertPriority priority, {
    Map<String, dynamic>? data,
  }) async {
    try {
      await _notificationService?.sendCrashAlert(
        title: title,
        message: message,
        data: data ?? {},
        priority: priority,
      );
    } catch (e) {
      dev.log('Error sending crash notification: $e');
    }
  }

  /// Collect device information
  Future<void> _collectDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _platform = 'Android';
        _osVersion = 'Android ${androidInfo.version.release}';
        _deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
        _deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _platform = 'iOS';
        _osVersion = 'iOS ${iosInfo.systemVersion}';
        _deviceModel = iosInfo.model;
        _deviceId = iosInfo.identifierForVendor;
      }
    } catch (e) {
      dev.log('Error collecting device info: $e');
      _platform = Platform.operatingSystem;
      _osVersion = 'Unknown';
      _deviceModel = 'Unknown';
      _deviceId = 'Unknown';
    }
  }

  /// Collect app information
  Future<void> _collectAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    } catch (e) {
      dev.log('Error collecting app info: $e');
      _appVersion = 'Unknown';
      _buildNumber = 'Unknown';
    }
  }

  /// Start a new user session
  Future<void> _startNewSession() async {
    try {
      _currentSessionId = const Uuid().v4();

      final userId = await _gateStorage?.getUserId();
      final selectedGate = await _gateStorage?.getSelectedGate();
      final gateId = selectedGate?['gate_id']?.toString();

      final session = UserSession(
        sessionId: _currentSessionId!,
        startTime: DateTime.now(),
        userId: userId,
        gateId: gateId,
        appVersion: _appVersion ?? 'Unknown',
        platform: _platform ?? 'Unknown',
      );

      await _sessionBox!.add(session);

      // Set up session timer to update periodically
      _sessionTimer?.cancel();
      _sessionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        _updateCurrentSession();
      });

      dev.log('Started new session: $_currentSessionId');
    } catch (e) {
      dev.log('Error starting new session: $e');
    }
  }

  /// Update current session
  Future<void> _updateCurrentSession() async {
    try {
      if (_currentSessionId == null) return;

      final session = _sessionBox!.values
          .where((s) => s.sessionId == _currentSessionId)
          .firstOrNull;

      if (session != null) {
        await session.save();
      }
    } catch (e) {
      dev.log('Error updating current session: $e');
    }
  }

  /// Update session crash count
  Future<void> _updateSessionCrashCount() async {
    try {
      if (_currentSessionId == null) return;

      final session = _sessionBox!.values
          .where((s) => s.sessionId == _currentSessionId)
          .firstOrNull;

      if (session != null) {
        await session.save();
      }
    } catch (e) {
      dev.log('Error updating session crash count: $e');
    }
  }

  /// Clean up old crash reports
  Future<void> _cleanupOldReports() async {
    try {
      final allCrashes = _crashBox!.values.toList();

      if (allCrashes.length > _maxCrashReports) {
        // Sort by timestamp and keep only the most recent
        allCrashes.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        final toDelete = allCrashes.skip(_maxCrashReports).toList();
        for (final crash in toDelete) {
          await crash.delete();
        }

        dev.log('Cleaned up ${toDelete.length} old crash reports');
      }
    } catch (e) {
      dev.log('Error cleaning up old reports: $e');
    }
  }

  /// Add custom key-value pair for debugging context
  void setCustomKey(String key, dynamic value) {
    _customKeys[key] = value;
  }

  /// Remove custom key
  void removeCustomKey(String key) {
    _customKeys.remove(key);
  }

  /// Add breadcrumb for debugging context
  void addBreadcrumb(String message, {Map<String, dynamic>? data}) {
    final breadcrumb = {
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
      'data': data ?? {},
    };

    _breadcrumbs.add(breadcrumb);

    // Keep only last 20 breadcrumbs
    if (_breadcrumbs.length > 20) {
      _breadcrumbs.removeAt(0);
    }
  }

  /// Get all crash reports
  List<CrashReport> getAllCrashReports() {
    return _crashBox?.values.toList() ?? [];
  }

  /// Get crash reports by filter
  List<CrashReport> getCrashReports({
    bool? isFatal,
    String? errorType,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    var crashes = _crashBox?.values.toList() ?? [];

    if (isFatal != null) {
      crashes = crashes.where((c) => c.isFatal == isFatal).toList();
    }

    if (errorType != null) {
      crashes = crashes.where((c) => c.errorType == errorType).toList();
    }

    if (startDate != null) {
      crashes = crashes.where((c) => c.timestamp.isAfter(startDate)).toList();
    }

    if (endDate != null) {
      crashes = crashes.where((c) => c.timestamp.isBefore(endDate)).toList();
    }

    // Sort by timestamp (newest first)
    crashes.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (limit != null && crashes.length > limit) {
      crashes = crashes.take(limit).toList();
    }

    return crashes;
  }

  /// Get crash statistics
  Map<String, dynamic> getCrashStatistics() {
    final crashes = getAllCrashReports();
    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));
    final last7Days = now.subtract(const Duration(days: 7));

    final totalCrashes = crashes.length;
    final fatalCrashes = crashes.where((c) => c.isFatal).length;
    final crashes24h =
        crashes.where((c) => c.timestamp.isAfter(last24Hours)).length;
    final crashes7d =
        crashes.where((c) => c.timestamp.isAfter(last7Days)).length;

    // Group by error signature
    final groupedCrashes = <String, List<CrashReport>>{};
    for (final crash in crashes) {
      final signature = crash.errorSignature ?? crash.generateErrorSignature();
      groupedCrashes.putIfAbsent(signature, () => []).add(crash);
    }

    return {
      'totalCrashes': totalCrashes,
      'fatalCrashes': fatalCrashes,
      'nonFatalCrashes': totalCrashes - fatalCrashes,
      'crashes24h': crashes24h,
      'crashes7d': crashes7d,
      'uniqueErrors': groupedCrashes.length,
      'crashGroups': groupedCrashes.map((k, v) => MapEntry(k, v.length)),
      'lastCrashTime': crashes.isNotEmpty ? crashes.first.timestamp : null,
    };
  }

  /// End current session
  Future<void> endCurrentSession() async {
    try {
      await _updateCurrentSession();
      _sessionTimer?.cancel();
      _currentSessionId = null;
      dev.log('Ended current session');
    } catch (e) {
      dev.log('Error ending current session: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _sessionTimer?.cancel();
    endCurrentSession();
  }
}
