import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';

/// Comprehensive PostHog Error Tracking Service
/// Captures and sends all application errors to PostHog Error Tracking dashboard
class PostHogErrorTrackingService {
  static final PostHogErrorTrackingService _instance =
      PostHogErrorTrackingService._internal();
  factory PostHogErrorTrackingService() => _instance;
  PostHogErrorTrackingService._internal();

  static PostHogErrorTrackingService get instance => _instance;

  bool _isInitialized = false;
  String? _userId;
  String? _sessionId;
  String? _gateId;
  Map<String, dynamic> _deviceInfo = {};
  Map<String, dynamic> _appInfo = {};
  String? _currentScreen;
  final Map<String, dynamic> _userContext = {};

  /// Initialize the PostHog Error Tracking Service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize PostHog first
      await _initializePostHog();

      // Collect device and app information
      await _collectDeviceInfo();
      await _collectAppInfo();
      await _loadUserContext();

      _isInitialized = true;
      dev.log('🔍 PostHog Error Tracking Service initialized');

      // Send initialization event
      await _sendEvent('error_tracking_initialized', {
        'service': 'posthog_error_tracking',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      dev.log('❌ Error initializing PostHog Error Tracking Service: $e');
    }
  }

  /// Initialize PostHog with proper configuration
  Future<void> _initializePostHog() async {
    try {
      // Load environment variables
      await dotenv.load(fileName: ".env");

      // PostHog should already be initialized in main.dart or analytics service
      // This service focuses on error tracking functionality
      dev.log(
          'PostHog Error Tracking Service ready (PostHog initialized elsewhere)');

      dev.log('✅ PostHog initialized for error tracking');
    } catch (e) {
      dev.log('❌ Error initializing PostHog: $e');
      // Continue without PostHog if initialization fails
    }
  }

  /// Set current user context
  void setUserContext({
    String? userId,
    String? sessionId,
    String? gateId,
    Map<String, dynamic>? additionalContext,
  }) {
    _userId = userId;
    _sessionId = sessionId;
    _gateId = gateId;
    if (additionalContext != null) {
      _userContext.addAll(additionalContext);
    }
  }

  /// Set current screen/page
  void setCurrentScreen(String screenName) {
    _currentScreen = screenName;
  }

  /// Capture and send error to PostHog Error Tracking
  Future<void> captureError({
    required dynamic error,
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalProperties,
    bool isFatal = false,
    String? errorType,
    String? userId,
  }) async {
    if (!_isInitialized) {
      dev.log('⚠️ PostHog Error Tracking Service not initialized');
      return;
    }

    try {
      final errorProperties = await _buildErrorProperties(
        error: error,
        stackTrace: stackTrace,
        context: context,
        additionalProperties: additionalProperties,
        isFatal: isFatal,
        errorType: errorType,
        userId: userId,
      );

      // Send to PostHog as an error event
      await _sendEvent('\$exception', errorProperties);

      dev.log(
          '✅ Error sent to PostHog: ${error.toString().substring(0, 100)}...');
    } catch (e) {
      dev.log('❌ Failed to send error to PostHog: $e');
    }
  }

  /// Capture Flutter framework errors
  Future<void> captureFlutterError(FlutterErrorDetails details) async {
    await captureError(
      error: details.exception,
      stackTrace: details.stack,
      context: 'flutter_framework',
      errorType: 'FlutterError',
      isFatal: false,
      additionalProperties: {
        'library': details.library,
        'context': details.context?.toString(),
        'information_collector': details.informationCollector?.toString(),
        'silent': details.silent,
      },
    );
  }

  /// Capture platform/Dart errors
  Future<void> capturePlatformError(
      dynamic error, StackTrace stackTrace) async {
    await captureError(
      error: error,
      stackTrace: stackTrace,
      context: 'platform_dart',
      errorType: 'PlatformError',
      isFatal: true,
      additionalProperties: {
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
      },
    );
  }

  /// Capture network errors
  Future<void> captureNetworkError({
    required dynamic error,
    String? url,
    String? method,
    int? statusCode,
    Map<String, dynamic>? requestData,
    Map<String, dynamic>? responseData,
  }) async {
    await captureError(
      error: error,
      context: 'network_request',
      errorType: 'NetworkError',
      isFatal: false,
      additionalProperties: {
        'url': url,
        'method': method,
        'status_code': statusCode,
        'request_data': requestData,
        'response_data': responseData,
      },
    );
  }

  /// Capture user action errors
  Future<void> captureUserActionError({
    required dynamic error,
    required String action,
    String? screen,
    Map<String, dynamic>? actionContext,
  }) async {
    await captureError(
      error: error,
      context: 'user_action',
      errorType: 'UserActionError',
      isFatal: false,
      additionalProperties: {
        'action': action,
        'screen': screen ?? _currentScreen,
        'action_context': actionContext,
      },
    );
  }

  /// Build comprehensive error properties for PostHog
  Future<Map<String, dynamic>> _buildErrorProperties({
    required dynamic error,
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalProperties,
    bool isFatal = false,
    String? errorType,
    String? userId,
  }) async {
    final timestamp = DateTime.now();

    return {
      // Error details
      '\$exception_type': errorType ?? error.runtimeType.toString(),
      '\$exception_message': error.toString(),
      '\$exception_stack_trace': stackTrace?.toString(),
      '\$exception_fingerprint': _generateErrorFingerprint(error, stackTrace),

      // PostHog Error Tracking specific fields
      '\$exception_level': isFatal ? 'fatal' : 'error',
      '\$exception_handled': !isFatal,

      // Context information
      'error_context': context ?? 'unknown',
      'current_screen': _currentScreen,
      'timestamp': timestamp.toIso8601String(),
      'is_fatal': isFatal,

      // User context
      'user_id': userId ?? _userId,
      'session_id': _sessionId,
      'gate_id': _gateId,

      // Device information
      'device_model': _deviceInfo['model'],
      'device_brand': _deviceInfo['brand'],
      'device_os': _deviceInfo['os'],
      'device_os_version': _deviceInfo['os_version'],
      'device_platform': _deviceInfo['platform'],

      // App information
      'app_version': _appInfo['version'],
      'app_build_number': _appInfo['build_number'],
      'app_package_name': _appInfo['package_name'],

      // Runtime information
      'flutter_version': _appInfo['flutter_version'],
      'dart_version': _appInfo['dart_version'],
      'debug_mode': kDebugMode,
      'release_mode': kReleaseMode,
      'profile_mode': kProfileMode,

      // Additional properties
      ...?additionalProperties,
      ..._userContext,
    };
  }

  /// Generate error fingerprint for deduplication
  String _generateErrorFingerprint(dynamic error, StackTrace? stackTrace) {
    final errorString = error.toString();
    final stackString = stackTrace?.toString() ?? '';

    // Create a simple hash based on error message and first few lines of stack trace
    final combined =
        '$errorString${stackString.split('\n').take(3).join('\n')}';
    return combined.hashCode.toString();
  }

  /// Send event to PostHog
  Future<void> _sendEvent(
      String eventName, Map<String, dynamic> properties) async {
    try {
      // Convert dynamic values to Object for PostHog compatibility
      final Map<String, Object> convertedProperties = {};
      properties.forEach((key, value) {
        if (value != null) {
          convertedProperties[key] = value;
        }
      });

      await Posthog().capture(
        eventName: eventName,
        properties: convertedProperties,
      );
    } catch (e) {
      dev.log('❌ Failed to send event to PostHog: $e');
    }
  }

  /// Collect device information
  Future<void> _collectDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceInfo = {
          'platform': 'android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'os': 'Android',
          'os_version': androidInfo.version.release,
          'sdk_int': androidInfo.version.sdkInt,
          'manufacturer': androidInfo.manufacturer,
          'device': androidInfo.device,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceInfo = {
          'platform': 'ios',
          'model': iosInfo.model,
          'brand': 'Apple',
          'os': 'iOS',
          'os_version': iosInfo.systemVersion,
          'name': iosInfo.name,
          'system_name': iosInfo.systemName,
        };
      } else {
        _deviceInfo = {
          'platform': Platform.operatingSystem,
          'os': Platform.operatingSystem,
          'os_version': Platform.operatingSystemVersion,
        };
      }
    } catch (e) {
      dev.log('Error collecting device info: $e');
      _deviceInfo = {'platform': 'unknown'};
    }
  }

  /// Collect app information
  Future<void> _collectAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appInfo = {
        'app_name': packageInfo.appName,
        'package_name': packageInfo.packageName,
        'version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
        'flutter_version': _getFlutterVersion(),
        'dart_version': Platform.version,
      };
    } catch (e) {
      dev.log('Error collecting app info: $e');
      _appInfo = {'version': 'unknown'};
    }
  }

  /// Load user context from storage
  Future<void> _loadUserContext() async {
    try {
      final gateStorage = GateStorage();
      await gateStorage.init();

      _userId = await gateStorage.getUserId();

      // Generate session ID from session timestamp or create new one
      final sessionTimestamp = await gateStorage.getSessionTimestamp();
      if (sessionTimestamp != null) {
        _sessionId = 'session_${sessionTimestamp.millisecondsSinceEpoch}';
      } else {
        _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Get gate ID from selected gate
      final selectedGate = await gateStorage.getSelectedGate();
      _gateId = selectedGate['id'];
    } catch (e) {
      dev.log('Error loading user context: $e');
    }
  }

  /// Get Flutter version (simplified)
  String _getFlutterVersion() {
    try {
      // This is a simplified version - in a real app you might want to
      // include this information in your build process
      return 'Flutter 3.x'; // Replace with actual version detection
    } catch (e) {
      return 'unknown';
    }
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose the service
  void dispose() {
    _isInitialized = false;
    _userId = null;
    _sessionId = null;
    _gateId = null;
    _deviceInfo.clear();
    _appInfo.clear();
    _currentScreen = null;
    _userContext.clear();
  }
}
