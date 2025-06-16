import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Comprehensive Sentry monitoring service for error tracking and performance monitoring
class SentryMonitoringService {
  static SentryMonitoringService? _instance;
  static SentryMonitoringService get instance =>
      _instance ??= SentryMonitoringService._();

  SentryMonitoringService._();

  bool _isInitialized = false;
  late String _environment;
  late String _release;
  final Map<String, dynamic> _userContext = {};
  Map<String, dynamic> _deviceInfo = {};

  /// Initialize Sentry with comprehensive configuration
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load environment variables
      await dotenv.load(fileName: ".env");

      // Get app and device info
      await _loadAppInfo();
      await _loadDeviceInfo();

      final sentryDsn = dotenv.env['SENTRY_DSN'];
      if (sentryDsn == null || sentryDsn.isEmpty) {
        dev.log('Sentry DSN not configured, skipping initialization');
        return;
      }

      await SentryFlutter.init(
        (options) {
          options.dsn = sentryDsn;
          options.environment = _environment;
          options.release = _release;

          // Performance monitoring
          options.tracesSampleRate = kDebugMode ? 1.0 : 0.2;
          options.profilesSampleRate = kDebugMode ? 1.0 : 0.1;

          // Error tracking configuration
          options.attachStacktrace = true;
          options.attachThreads = true;
          options.sendDefaultPii = false;
          options.maxBreadcrumbs = 100;

          // Debug configuration
          options.debug = kDebugMode;
          options.diagnosticLevel =
              kDebugMode ? SentryLevel.debug : SentryLevel.warning;

          // Session tracking
          options.enableAutoSessionTracking = true;
          // options.sessionTrackingIntervalMillis = 30000; // Deprecated in newer Sentry versions

          // Performance monitoring options
          options.enableAutoPerformanceTracing = true;
          options.enableUserInteractionTracing = true;
          options.enableAppHangTracking = true;

          // Custom tags - initialScope is deprecated in newer Sentry versions
          // Will be set via configureScope after initialization
          // options.initialScope = (scope) {
          //   scope.setTag('platform', 'flutter');
          //   scope.setTag('app', 'onegate');
          //   scope.setContext('device', _deviceInfo);
          //   scope.setContext('app_info', {
          //     'version': _release,
          //     'environment': _environment,
          //     'debug_mode': kDebugMode,
          //   });
          // };

          // Before send callback for filtering
          options.beforeSend = _beforeSendCallback;
          options.beforeSendTransaction = _beforeSendTransactionCallback;
        },
      );

      _isInitialized = true;
      dev.log('Sentry monitoring service initialized successfully');

      // Set initial user context
      await _updateUserContext();

      // Add initial breadcrumb
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'Sentry monitoring service initialized',
        level: SentryLevel.info,
        category: 'initialization',
        timestamp: DateTime.now(),
      ));
    } catch (e, stackTrace) {
      dev.log('Error initializing Sentry: $e');
      dev.log('Stack trace: $stackTrace');
    }
  }

  /// Load application information
  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _release = '${packageInfo.version}+${packageInfo.buildNumber}';
      _environment = kDebugMode ? 'development' : 'production';
    } catch (e) {
      _release = '1.0.0+1';
      _environment = kDebugMode ? 'development' : 'production';
      dev.log('Error loading app info: $e');
    }
  }

  /// Load device information
  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceInfo = {
          'platform': 'android',
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'version': androidInfo.version.release,
          'sdk_int': androidInfo.version.sdkInt,
          'brand': androidInfo.brand,
          'device': androidInfo.device,
        };
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceInfo = {
          'platform': 'ios',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'system_name': iosInfo.systemName,
          'system_version': iosInfo.systemVersion,
          'localized_model': iosInfo.localizedModel,
        };
      } else {
        _deviceInfo = {
          'platform': defaultTargetPlatform.name,
        };
      }
    } catch (e) {
      _deviceInfo = {'platform': 'unknown'};
      dev.log('Error loading device info: $e');
    }
  }

  /// Update user context information
  Future<void> _updateUserContext() async {
    if (!_isInitialized) return;

    try {
      await Sentry.configureScope((scope) {
        scope.setUser(SentryUser(
          id: _userContext['user_id']?.toString(),
          email: _userContext['email']?.toString(),
          username: _userContext['username']?.toString(),
          data: _userContext,
        ));
      });
    } catch (e) {
      dev.log('Error updating user context: $e');
    }
  }

  /// Before send callback for filtering events
  SentryEvent? _beforeSendCallback(SentryEvent event, {Hint? hint}) {
    // Filter out debug events in production
    if (!kDebugMode && event.level == SentryLevel.debug) {
      return null;
    }

    // Add custom tags
    event = event.copyWith(
      tags: {
        ...?event.tags,
        'source': 'flutter_app',
        'platform': defaultTargetPlatform.name,
      },
    );

    return event;
  }

  /// Before send transaction callback for filtering performance data
  SentryTransaction? _beforeSendTransactionCallback(
      SentryTransaction transaction) {
    // Filter out very short transactions
    // Note: duration property may not be available in all Sentry versions
    // if (transaction.duration != null &&
    //     transaction.duration!.inMilliseconds < 10) {
    //   return null;
    // }

    return transaction;
  }

  /// Set user context
  Future<void> setUser({
    String? userId,
    String? email,
    String? username,
    Map<String, dynamic>? extras,
  }) async {
    if (!_isInitialized) return;

    _userContext.clear();
    if (userId != null) _userContext['user_id'] = userId;
    if (email != null) _userContext['email'] = email;
    if (username != null) _userContext['username'] = username;
    if (extras != null) _userContext.addAll(extras);

    await _updateUserContext();
  }

  /// Clear user context
  Future<void> clearUser() async {
    if (!_isInitialized) return;

    _userContext.clear();
    await Sentry.configureScope((scope) => scope.setUser(null));
  }

  /// Capture an exception with context
  Future<SentryId> captureException(
    dynamic exception, {
    dynamic stackTrace,
    String? fingerprint,
    SentryLevel? level,
    Map<String, dynamic>? extra,
    Map<String, String>? tags,
  }) async {
    if (!_isInitialized) {
      dev.log('Sentry not initialized, logging exception: $exception');
      return const SentryId.empty();
    }

    try {
      return await Sentry.captureException(
        exception,
        stackTrace: stackTrace,
        withScope: (scope) {
          if (fingerprint != null) scope.fingerprint = [fingerprint];
          if (level != null) scope.level = level;
          if (extra != null) {
            extra.forEach((key, value) => scope.setExtra(key, value));
          }
          if (tags != null) {
            tags.forEach((key, value) => scope.setTag(key, value));
          }
        },
      );
    } catch (e) {
      dev.log('Error capturing exception to Sentry: $e');
      return const SentryId.empty();
    }
  }

  /// Capture a message with context
  Future<SentryId> captureMessage(
    String message, {
    SentryLevel? level,
    String? fingerprint,
    Map<String, dynamic>? extra,
    Map<String, String>? tags,
  }) async {
    if (!_isInitialized) {
      dev.log('Sentry not initialized, logging message: $message');
      return const SentryId.empty();
    }

    try {
      return await Sentry.captureMessage(
        message,
        level: level ?? SentryLevel.info,
        withScope: (scope) {
          if (fingerprint != null) scope.fingerprint = [fingerprint];
          if (extra != null) {
            extra.forEach((key, value) => scope.setExtra(key, value));
          }
          if (tags != null) {
            tags.forEach((key, value) => scope.setTag(key, value));
          }
        },
      );
    } catch (e) {
      dev.log('Error capturing message to Sentry: $e');
      return const SentryId.empty();
    }
  }

  /// Add a breadcrumb
  void addBreadcrumb({
    required String message,
    String? category,
    SentryLevel? level,
    Map<String, dynamic>? data,
  }) {
    if (!_isInitialized) return;

    try {
      Sentry.addBreadcrumb(Breadcrumb(
        message: message,
        category: category,
        level: level ?? SentryLevel.info,
        data: data,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      dev.log('Error adding breadcrumb to Sentry: $e');
    }
  }

  /// Start a performance transaction
  ISentrySpan startTransaction({
    required String name,
    required String operation,
    String? description,
    Map<String, dynamic>? data,
  }) {
    if (!_isInitialized) {
      return NoOpSentrySpan();
    }

    try {
      final transaction =
          Sentry.startTransaction(name, operation, description: description);

      if (data != null) {
        data.forEach((key, value) {
          transaction.setData(key, value);
        });
      }

      return transaction;
    } catch (e) {
      dev.log('Error starting transaction: $e');
      return NoOpSentrySpan();
    }
  }

  /// Track screen navigation
  void trackScreenView(String screenName, {Map<String, dynamic>? extras}) {
    addBreadcrumb(
      message: 'Screen: $screenName',
      category: 'navigation',
      level: SentryLevel.info,
      data: {
        'screen_name': screenName,
        'timestamp': DateTime.now().toIso8601String(),
        ...?extras,
      },
    );
  }

  /// Track user action
  void trackUserAction(String action, {Map<String, dynamic>? extras}) {
    addBreadcrumb(
      message: 'User action: $action',
      category: 'user_interaction',
      level: SentryLevel.info,
      data: {
        'action': action,
        'timestamp': DateTime.now().toIso8601String(),
        ...?extras,
      },
    );
  }

  /// Track network request
  void trackNetworkRequest({
    required String url,
    required String method,
    int? statusCode,
    Duration? duration,
    Map<String, dynamic>? extras,
  }) {
    addBreadcrumb(
      message: 'Network: $method $url',
      category: 'http',
      level: statusCode != null && statusCode >= 400
          ? SentryLevel.warning
          : SentryLevel.info,
      data: {
        'url': url,
        'method': method,
        'status_code': statusCode,
        'duration_ms': duration?.inMilliseconds,
        'timestamp': DateTime.now().toIso8601String(),
        ...?extras,
      },
    );
  }

  /// Get current user context
  Map<String, dynamic> get userContext => Map.from(_userContext);

  /// Check if Sentry is initialized
  bool get isInitialized => _isInitialized;

  /// Get current environment
  String get environment => _environment;

  /// Get current release
  String get release => _release;

  /// Dispose resources
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      await Sentry.close();
      _isInitialized = false;
      dev.log('Sentry monitoring service disposed');
    } catch (e) {
      dev.log('Error disposing Sentry: $e');
    }
  }
}
