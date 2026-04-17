import 'dart:async';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/main.dart';
import 'package:flutter_onegate/presentation/widgets/session_expired_bottom_sheet.dart';
import 'package:flutter_onegate/services/session_manager/continuous_session_manager.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exception thrown when refresh token operations fail
class RefreshTokenException implements Exception {
  final String message;
  final dynamic originalError;
  final int? statusCode;
  final RefreshTokenFailureType type;

  const RefreshTokenException(
    this.message, {
    this.originalError,
    this.statusCode,
    this.type = RefreshTokenFailureType.unknown,
  });

  @override
  String toString() => 'RefreshTokenException: $message';
}

/// Types of refresh token failures
enum RefreshTokenFailureType {
  // Network-related failures
  networkTimeout,
  networkUnavailable,
  connectionError,

  // Authentication failures
  refreshTokenExpired,
  refreshTokenRevoked,
  refreshTokenInvalid,
  missingRefreshToken,

  // Server-side failures
  serverError,
  serviceUnavailable,
  invalidResponse,

  // Client-side failures
  storageError,
  configurationError,

  // Unknown failures
  unknown,
}

/// Resolution strategies for refresh token failures
enum RefreshTokenResolution {
  retryImmediate,
  retryWithBackoff,
  showUserError,
  forceReauth,
  deactivateSession,
}

/// Comprehensive refresh token failure analysis and handling service
class RefreshTokenErrorHandler {
  static const int _maxRetryAttempts = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 2);
  static const Duration _maxRetryDelay = Duration(seconds: 30);
  static const int _maxConsecutiveFailures = 5;

  // Failure tracking
  static int _consecutiveFailures = 0;
  static DateTime? _lastFailureTime;
  static RefreshTokenFailureType? _lastFailureType;

  /// Analyze the type of refresh token failure
  static RefreshTokenFailureType analyzeFailure(dynamic error) {
    if (error is DioException) {
      return _analyzeDioException(error);
    }

    if (error is RefreshTokenException) {
      return error.type;
    }

    final errorString = error.toString().toLowerCase();

    // Network-related failures
    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return RefreshTokenFailureType.networkTimeout;
    }

    if (errorString.contains('network') || errorString.contains('connection')) {
      return RefreshTokenFailureType.connectionError;
    }

    // Authentication failures
    if (errorString.contains('expired') ||
        errorString.contains('invalid_grant')) {
      return RefreshTokenFailureType.refreshTokenExpired;
    }

    if (errorString.contains('revoked') ||
        errorString.contains('unauthorized')) {
      return RefreshTokenFailureType.refreshTokenRevoked;
    }

    if (errorString.contains('invalid') || errorString.contains('malformed')) {
      return RefreshTokenFailureType.refreshTokenInvalid;
    }

    // Storage failures
    if (errorString.contains('storage') || errorString.contains('secure')) {
      return RefreshTokenFailureType.storageError;
    }

    return RefreshTokenFailureType.unknown;
  }

  /// Analyze DioException for specific failure types
  static RefreshTokenFailureType _analyzeDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return RefreshTokenFailureType.networkTimeout;

      case DioExceptionType.connectionError:
        return RefreshTokenFailureType.networkUnavailable;

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) {
          return RefreshTokenFailureType.refreshTokenExpired;
        } else if (statusCode == 403) {
          return RefreshTokenFailureType.refreshTokenRevoked;
        } else if (statusCode != null && statusCode >= 500) {
          return RefreshTokenFailureType.serverError;
        }
        return RefreshTokenFailureType.invalidResponse;

      default:
        return RefreshTokenFailureType.unknown;
    }
  }

  /// Determine if a failure type should be retried
  static bool shouldRetryFailure(RefreshTokenFailureType type) {
    switch (type) {
      case RefreshTokenFailureType.networkTimeout:
      case RefreshTokenFailureType.networkUnavailable:
      case RefreshTokenFailureType.connectionError:
      case RefreshTokenFailureType.serverError:
      case RefreshTokenFailureType.serviceUnavailable:
      case RefreshTokenFailureType.storageError:
        return true;

      case RefreshTokenFailureType.refreshTokenExpired:
      case RefreshTokenFailureType.refreshTokenRevoked:
      case RefreshTokenFailureType.refreshTokenInvalid:
      case RefreshTokenFailureType.missingRefreshToken:
      case RefreshTokenFailureType.configurationError:
        return false;

      case RefreshTokenFailureType.invalidResponse:
      case RefreshTokenFailureType.unknown:
        return true; // Give it a chance
    }
  }

  /// Calculate exponential backoff delay
  static Duration calculateBackoffDelay(int attemptNumber) {
    final baseDelayMs = _baseRetryDelay.inMilliseconds;
    final exponentialDelay = baseDelayMs * (1 << (attemptNumber - 1));
    final cappedDelay = exponentialDelay.clamp(
      baseDelayMs,
      _maxRetryDelay.inMilliseconds,
    );
    return Duration(milliseconds: cappedDelay);
  }

  /// Handle refresh token failure with comprehensive analysis
  static Future<RefreshTokenResolution> handleRefreshTokenFailure(
    dynamic error,
    int attemptNumber,
    RefreshTokenFailureType? failureType,
  ) async {
    try {
      final type = failureType ?? analyzeFailure(error);

      // Track failure
      _consecutiveFailures++;
      _lastFailureTime = DateTime.now();
      _lastFailureType = type;

      log("❌ Refresh token failure #$_consecutiveFailures: $type (attempt $attemptNumber)");

      // Determine resolution strategy
      final resolution = _determineResolutionStrategy(type, attemptNumber);

      // Execute resolution
      await _executeResolution(resolution, type, error);

      return resolution;
    } catch (e) {
      log("❌ Error handling refresh token failure: $e");
      return RefreshTokenResolution.forceReauth;
    }
  }

  /// Determine the appropriate resolution strategy
  static RefreshTokenResolution _determineResolutionStrategy(
    RefreshTokenFailureType type,
    int attemptNumber,
  ) {
    // If too many consecutive failures, force reauth
    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      return RefreshTokenResolution.forceReauth;
    }

    // If max attempts reached for this request
    if (attemptNumber >= _maxRetryAttempts) {
      if (_isAuthenticationFailure(type)) {
        return RefreshTokenResolution.forceReauth;
      } else {
        return RefreshTokenResolution.showUserError;
      }
    }

    // Determine strategy based on failure type
    switch (type) {
      case RefreshTokenFailureType.refreshTokenExpired:
      case RefreshTokenFailureType.refreshTokenRevoked:
      case RefreshTokenFailureType.refreshTokenInvalid:
      case RefreshTokenFailureType.missingRefreshToken:
        return RefreshTokenResolution.forceReauth;

      case RefreshTokenFailureType.networkTimeout:
      case RefreshTokenFailureType.networkUnavailable:
      case RefreshTokenFailureType.connectionError:
        return RefreshTokenResolution.retryWithBackoff;

      case RefreshTokenFailureType.serverError:
      case RefreshTokenFailureType.serviceUnavailable:
        return RefreshTokenResolution.retryWithBackoff;

      case RefreshTokenFailureType.storageError:
        return RefreshTokenResolution.retryImmediate;

      case RefreshTokenFailureType.configurationError:
        return RefreshTokenResolution.showUserError;

      default:
        return RefreshTokenResolution.retryWithBackoff;
    }
  }

  /// Check if failure type indicates authentication failure
  static bool _isAuthenticationFailure(RefreshTokenFailureType type) {
    return [
      RefreshTokenFailureType.refreshTokenExpired,
      RefreshTokenFailureType.refreshTokenRevoked,
      RefreshTokenFailureType.refreshTokenInvalid,
      RefreshTokenFailureType.missingRefreshToken,
    ].contains(type);
  }

  /// Execute the determined resolution strategy
  static Future<void> _executeResolution(
    RefreshTokenResolution resolution,
    RefreshTokenFailureType failureType,
    dynamic error,
  ) async {
    switch (resolution) {
      case RefreshTokenResolution.retryImmediate:
        log("🔄 Executing immediate retry for: $failureType");
        break;

      case RefreshTokenResolution.retryWithBackoff:
        log("🔄 Executing retry with backoff for: $failureType");
        break;

      case RefreshTokenResolution.showUserError:
        log("👤 Showing user error for: $failureType");
        await _showUserErrorDialog(failureType, error);
        break;

      case RefreshTokenResolution.forceReauth:
        log("🚪 Forcing reauthentication for: $failureType");
        await _forceReauthentication(failureType);
        break;

      case RefreshTokenResolution.deactivateSession:
        log("🔒 Deactivating continuous session for: $failureType");
        await _deactivateContinuousSession(failureType);
        break;
    }
  }

  /// Show user error dialog for recoverable failures
  static Future<void> _showUserErrorDialog(
    RefreshTokenFailureType failureType,
    dynamic error,
  ) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final userMessage = _getUserFriendlyMessage(failureType);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Connection Issue')),
        content: Text(userMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Trigger manual retry if retryable
              if (shouldRetryFailure(failureType)) {
                _triggerManualRetry();
              }
            },
            child: Text(
              shouldRetryFailure(failureType)
                  ? context.tr('Try Again')
                  : context.tr('OK'),
            ),
          ),
          if (shouldRetryFailure(failureType))
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _forceReauthentication(failureType);
              },
              child: Text(context.tr('Login Again')),
            ),
        ],
      ),
    );
  }

  /// Force reauthentication flow
  static Future<void> _forceReauthentication(
      RefreshTokenFailureType failureType) async {
    try {
      log("🚪 Starting forced reauthentication for: $failureType");

      // Check if continuous session should override refresh token expiration
      final shouldOverride =
          await _shouldOverrideRefreshTokenExpiration(failureType);

      if (shouldOverride) {
        log("🔒 Continuous session overriding refresh token expiration - maintaining session");
        await _handleContinuousSessionOverride(failureType);
        return;
      }

      // Deactivate continuous session first
      await _deactivateContinuousSession(failureType);

      // Show session expired modal
      await showSessionExpiredBottomSheet(
        errorMessage: _getSessionExpiredMessage(failureType),
        onLoginComplete: () {
          resetFailureCounters();
        },
      );
    } catch (e) {
      log("❌ Error during forced reauthentication: $e");
      // Fallback to direct navigation
      _navigateToLogin();
    }
  }

  /// Check if continuous session should override refresh token expiration
  static Future<bool> _shouldOverrideRefreshTokenExpiration(
      RefreshTokenFailureType failureType) async {
    try {
      // Only override for refresh token expiration, not other failures
      if (failureType != RefreshTokenFailureType.refreshTokenExpired) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();

      // Check if continuous session mode is active
      final tokenExpirationLogoutDisabled =
          prefs.getBool('token_expiration_logout_disabled') ?? false;
      final autoLogoutDisabled = prefs.getBool('auto_logout_disabled') ?? false;
      final continuousSessionActive =
          prefs.getBool('continuous_session_active') ?? false;

      // Check for specific 10-minute refresh token override
      final tenMinuteTokenOverride =
          prefs.getBool('ten_minute_refresh_token_override') ?? false;
      final shortRefreshTokenOverride =
          prefs.getBool('short_refresh_token_override') ?? false;

      final isContinuousSessionMode = tokenExpirationLogoutDisabled ||
          autoLogoutDisabled ||
          continuousSessionActive ||
          tenMinuteTokenOverride ||
          shortRefreshTokenOverride;

      log("🔍 Continuous session override check:");
      log("   • Failure Type: $failureType");
      log("   • Token Expiration Logout Disabled: $tokenExpirationLogoutDisabled");
      log("   • Auto Logout Disabled: $autoLogoutDisabled");
      log("   • Continuous Session Active: $continuousSessionActive");
      log("   • 10-Minute Token Override: $tenMinuteTokenOverride");
      log("   • Short Refresh Token Override: $shortRefreshTokenOverride");
      log("   • Should Override: $isContinuousSessionMode");

      return isContinuousSessionMode;
    } catch (e) {
      log("❌ Error checking continuous session override: $e");
      return false;
    }
  }

  /// Handle continuous session override for refresh token expiration
  static Future<void> _handleContinuousSessionOverride(
      RefreshTokenFailureType failureType) async {
    try {
      log("🔄 Handling continuous session override for: $failureType");

      // Instead of forcing logout, trigger a fresh login to get new tokens
      // while maintaining the session state
      await _triggerSilentTokenRenewal();
    } catch (e) {
      log("❌ Error handling continuous session override: $e");
      // Fallback to normal reauthentication
      await _deactivateContinuousSession(failureType);
      await showSessionExpiredBottomSheet(
        errorMessage: _getSessionExpiredMessage(failureType),
        onLoginComplete: () {
          resetFailureCounters();
        },
      );
    }
  }

  /// Trigger silent token renewal for continuous session
  static Future<void> _triggerSilentTokenRenewal() async {
    try {
      log("🔄 Triggering silent token renewal for continuous session");

      // Show a non-blocking notification instead of modal
      await _showTokenRenewalNotification();

      // Navigate to login but preserve session state
      await _navigateToLoginWithSessionPreservation();
    } catch (e) {
      log("❌ Error during silent token renewal: $e");
    }
  }

  /// Show token renewal notification instead of blocking modal
  static Future<void> _showTokenRenewalNotification() async {
    try {
      // You can implement a toast or snackbar here instead of modal
      log("📱 Token renewal required - showing notification");
      // TODO: Implement non-blocking notification
    } catch (e) {
      log("❌ Error showing token renewal notification: $e");
    }
  }

  /// Navigate to login while preserving session state
  static Future<void> _navigateToLoginWithSessionPreservation() async {
    try {
      log("🔄 Navigating to login with session preservation");

      final prefs = await SharedPreferences.getInstance();

      // Mark that this is a token renewal, not a logout
      await prefs.setBool('is_token_renewal', true);
      await prefs.setBool('preserve_continuous_session', true);

      _navigateToLogin();
    } catch (e) {
      log("❌ Error navigating to login with session preservation: $e");
    }
  }

  /// Deactivate continuous session
  static Future<void> _deactivateContinuousSession(
      RefreshTokenFailureType failureType) async {
    try {
      log("🔒 Deactivating continuous session due to: $failureType");

      final continuousSessionManager = GetIt.I<ContinuousSessionManager>();
      await continuousSessionManager.deactivateContinuousSession();

      log("✅ Continuous session deactivated successfully");
    } catch (e) {
      log("❌ Error deactivating continuous session: $e");
    }
  }

  /// Get user-friendly error message
  static String _getUserFriendlyMessage(RefreshTokenFailureType failureType) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      return _getDefaultUserFriendlyMessage(failureType);
    }

    switch (failureType) {
      case RefreshTokenFailureType.networkTimeout:
        return context.tr(
          'Connection timed out. Please check your internet connection and try again.',
        );
      case RefreshTokenFailureType.networkUnavailable:
        return context.tr(
          'No internet connection available. Please check your network settings.',
        );
      case RefreshTokenFailureType.connectionError:
        return context.tr(
          'Unable to connect to the server. Please try again later.',
        );
      case RefreshTokenFailureType.serverError:
        return context.tr(
          'Server is temporarily unavailable. Please try again in a few moments.',
        );
      case RefreshTokenFailureType.serviceUnavailable:
        return context.tr(
          'Service is currently under maintenance. Please try again later.',
        );
      case RefreshTokenFailureType.storageError:
        return context.tr(
          'Unable to access secure storage. Please restart the app.',
        );
      case RefreshTokenFailureType.configurationError:
        return context.tr('App configuration error. Please contact support.');
      default:
        return context.tr(
          'An unexpected error occurred. Please try again or contact support.',
        );
    }
  }

  /// Get session expired message
  static String _getSessionExpiredMessage(RefreshTokenFailureType failureType) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      return _getDefaultSessionExpiredMessage(failureType);
    }

    switch (failureType) {
      case RefreshTokenFailureType.refreshTokenExpired:
        return context.tr(
          'Your session has expired. Please log in again to continue.',
        );
      case RefreshTokenFailureType.refreshTokenRevoked:
        return context.tr(
          'Your session has been revoked for security reasons. Please log in again.',
        );
      case RefreshTokenFailureType.refreshTokenInvalid:
        return context
            .tr('Session authentication failed. Please log in again.');
      case RefreshTokenFailureType.missingRefreshToken:
        return context
            .tr('Session information is missing. Please log in again.');
      default:
        return context.tr(
          'Your session has expired. Please log in again to continue.',
        );
    }
  }

  static String _getDefaultUserFriendlyMessage(
    RefreshTokenFailureType failureType,
  ) {
    switch (failureType) {
      case RefreshTokenFailureType.networkTimeout:
        return 'Connection timed out. Please check your internet connection and try again.';
      case RefreshTokenFailureType.networkUnavailable:
        return 'No internet connection available. Please check your network settings.';
      case RefreshTokenFailureType.connectionError:
        return 'Unable to connect to the server. Please try again later.';
      case RefreshTokenFailureType.serverError:
        return 'Server is temporarily unavailable. Please try again in a few moments.';
      case RefreshTokenFailureType.serviceUnavailable:
        return 'Service is currently under maintenance. Please try again later.';
      case RefreshTokenFailureType.storageError:
        return 'Unable to access secure storage. Please restart the app.';
      case RefreshTokenFailureType.configurationError:
        return 'App configuration error. Please contact support.';
      default:
        return 'An unexpected error occurred. Please try again or contact support.';
    }
  }

  static String _getDefaultSessionExpiredMessage(
    RefreshTokenFailureType failureType,
  ) {
    switch (failureType) {
      case RefreshTokenFailureType.refreshTokenExpired:
        return 'Your session has expired. Please log in again to continue.';
      case RefreshTokenFailureType.refreshTokenRevoked:
        return 'Your session has been revoked for security reasons. Please log in again.';
      case RefreshTokenFailureType.refreshTokenInvalid:
        return 'Session authentication failed. Please log in again.';
      case RefreshTokenFailureType.missingRefreshToken:
        return 'Session information is missing. Please log in again.';
      default:
        return 'Your session has expired. Please log in again to continue.';
    }
  }

  /// Trigger manual retry
  static void _triggerManualRetry() {
    log("🔄 Manual retry triggered by user");
    // This will be handled by the calling component
  }

  /// Navigate to login screen
  static void _navigateToLogin() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  /// Reset failure counters on successful refresh
  static void resetFailureCounters() {
    _consecutiveFailures = 0;
    _lastFailureTime = null;
    _lastFailureType = null;
    log("✅ Refresh token failure counters reset");
  }

  /// Get current failure statistics
  static Map<String, dynamic> getFailureStatistics() {
    return {
      'consecutiveFailures': _consecutiveFailures,
      'lastFailureTime': _lastFailureTime?.toIso8601String(),
      'lastFailureType': _lastFailureType?.toString(),
    };
  }
}
