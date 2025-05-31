import 'dart:async';
import 'dart:developer';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/keycloack_config.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/auth_service/token_notification_service.dart';

/// Enhanced token refresh manager with automatic refresh capabilities
class EnhancedTokenRefreshManager {
  static final EnhancedTokenRefreshManager _instance =
      EnhancedTokenRefreshManager._internal();
  factory EnhancedTokenRefreshManager() => _instance;
  EnhancedTokenRefreshManager._internal();

  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Storage keys
  static const String _accessTokenKey = 'access_token_secure';
  static const String _refreshTokenKey = 'refresh_token_secure';
  static const String _idTokenKey = 'id_token_secure';

  // Refresh state management
  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;
  Timer? _refreshTimer;

  // Dependencies
  GateStorage? _gateStorage;
  final TokenNotificationService _notificationService =
      TokenNotificationService();

  // Configuration - Updated for dynamic refresh system
  static const Duration _fallbackRefreshBuffer =
      Duration(minutes: 1); // Fallback when dynamic calculation fails
  static const Duration _refreshCheckInterval =
      Duration(seconds: 30); // More frequent for precision
  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 5);

  // Dynamic refresh buffer (calculated per token)
  Duration? _dynamicRefreshBuffer;

  /// Initialize the token refresh manager
  Future<void> initialize(GateStorage gateStorage) async {
    _gateStorage = gateStorage;
    await _startPeriodicRefreshCheck();
    log("✅ EnhancedTokenRefreshManager initialized with dynamic refresh system");
  }

  /// Calculate dynamic refresh buffer for a given token
  Duration calculateDynamicRefreshBuffer(String accessToken) {
    try {
      final buffer = JwtTokenUtility.calculateOptimalRefreshBuffer(accessToken);
      _dynamicRefreshBuffer = buffer;
      log("📊 Dynamic refresh buffer calculated: ${buffer.inMinutes} minutes");
      return buffer;
    } catch (e) {
      log("❌ Error calculating dynamic refresh buffer: $e");
      _dynamicRefreshBuffer = _fallbackRefreshBuffer;
      return _fallbackRefreshBuffer;
    }
  }

  /// Get current refresh buffer (dynamic or fallback)
  Duration get currentRefreshBuffer {
    return _dynamicRefreshBuffer ?? _fallbackRefreshBuffer;
  }

  /// Start periodic token refresh checks
  Future<void> _startPeriodicRefreshCheck() async {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshCheckInterval, (timer) async {
      await _checkAndRefreshTokenIfNeeded();
    });
    log("🔄 Started periodic token refresh checks (every ${_refreshCheckInterval.inMinutes} minutes)");
  }

  /// Stop periodic token refresh checks
  void stopPeriodicRefreshCheck() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    log("⏹️ Stopped periodic token refresh checks");
  }

  /// Check if token needs refresh and refresh if necessary (with dynamic buffer)
  Future<bool> _checkAndRefreshTokenIfNeeded() async {
    try {
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      if (accessToken == null) {
        log("⚠️ No access token found during periodic check");
        return false;
      }

      // Calculate dynamic buffer for current token
      final buffer = calculateDynamicRefreshBuffer(accessToken);

      // Check if token is expiring soon using dynamic buffer
      if (JwtTokenUtility.isTokenExpiredOrExpiring(accessToken,
          buffer: buffer)) {
        log("🔄 Token is expiring soon, initiating automatic refresh (buffer: ${buffer.inMinutes} min)");

        // Show expiration warning if token expires within 10 minutes
        final timeUntilExpiration =
            JwtTokenUtility.getTimeUntilExpiration(accessToken);
        if (timeUntilExpiration != null &&
            timeUntilExpiration.inMinutes <= 10) {
          _notificationService.showTokenExpirationWarning(timeUntilExpiration);
        }

        return await refreshTokenIfNeeded();
      }

      return true;
    } catch (e) {
      log("❌ Error during periodic token check: $e");
      return false;
    }
  }

  /// Get a valid access token, refreshing if necessary (with dynamic buffer)
  Future<String?> getValidAccessToken() async {
    try {
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      if (accessToken == null) {
        log("❌ No access token available");
        return null;
      }

      // Calculate dynamic buffer for current token
      final buffer = calculateDynamicRefreshBuffer(accessToken);

      // Check if token is valid and not expiring soon using dynamic buffer
      if (!JwtTokenUtility.isTokenExpiredOrExpiring(accessToken,
          buffer: buffer)) {
        return accessToken;
      }

      // Token is expiring, refresh it
      log("🔄 Access token is expiring, attempting refresh (buffer: ${buffer.inMinutes} min)");
      final refreshed = await refreshTokenIfNeeded();
      if (refreshed) {
        return await _secureStorage.read(key: _accessTokenKey);
      }

      return null;
    } catch (e) {
      log("❌ Error getting valid access token: $e");
      return null;
    }
  }

  /// Enhanced method for immediate token validation and refresh (401 error fix with dynamic buffer)
  Future<String?> getValidAccessTokenWithImmediateRefresh() async {
    try {
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      if (accessToken == null) {
        log("❌ No access token available for immediate refresh");
        return null;
      }

      // Use more aggressive buffer for immediate refresh (minimum 30 seconds)
      final dynamicBuffer = calculateDynamicRefreshBuffer(accessToken);
      final immediateBuffer = Duration(
          seconds: (dynamicBuffer.inSeconds * 0.5)
              .clamp(30, dynamicBuffer.inSeconds)
              .toInt());

      // Check if token is expired or expiring soon using immediate buffer
      if (JwtTokenUtility.isTokenExpiredOrExpiring(accessToken,
          buffer: immediateBuffer)) {
        log("🔄 Token expiring within ${immediateBuffer.inSeconds} seconds, forcing immediate refresh");

        final refreshed = await refreshTokenIfNeeded();
        if (refreshed) {
          final newToken = await _secureStorage.read(key: _accessTokenKey);
          log("✅ Immediate token refresh successful");

          // Recalculate buffer for new token
          if (newToken != null) {
            calculateDynamicRefreshBuffer(newToken);
          }

          return newToken;
        } else {
          log("❌ Immediate token refresh failed");
          return null;
        }
      }

      log("✅ Token is valid for immediate use");
      return accessToken;
    } catch (e) {
      log("❌ Error getting valid access token with immediate refresh: $e");
      return null;
    }
  }

  /// Refresh token if needed with concurrency control
  Future<bool> refreshTokenIfNeeded() async {
    // If already refreshing, wait for the current refresh to complete
    if (_isRefreshing && _refreshCompleter != null) {
      log("⏳ Token refresh already in progress, waiting...");
      return await _refreshCompleter!.future;
    }

    // Start new refresh process
    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    // Show refresh progress notification
    _notificationService.showTokenRefreshProgress();

    try {
      final result = await _performTokenRefresh();

      if (result) {
        // Get the new token to show in success notification
        final newToken = await _secureStorage.read(key: _accessTokenKey);
        _notificationService.showTokenRefreshSuccess(newToken: newToken);
      } else {
        _notificationService.showTokenRefreshFailure();
      }

      _refreshCompleter!.complete(result);
      return result;
    } catch (e) {
      log("❌ Token refresh failed: $e");
      _notificationService.showTokenRefreshFailure(errorMessage: e.toString());
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  /// Perform the actual token refresh with retry logic
  Future<bool> _performTokenRefresh() async {
    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        log("🔄 Token refresh attempt $attempt/$_maxRetryAttempts");

        final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
        if (refreshToken == null) {
          log("❌ No refresh token available");
          return false;
        }

        // Use flutter_appauth for token refresh
        final tokenResponse = await _appAuth.token(
          AppAuthConfigManager.getRefreshTokenRequest(refreshToken),
        );

        if (tokenResponse.accessToken == null) {
          log("❌ Token refresh failed - no access token received");
          if (attempt < _maxRetryAttempts) {
            log("⏳ Retrying in ${_retryDelay.inSeconds} seconds...");
            await Future.delayed(_retryDelay);
            continue;
          }
          return false;
        }

        // Store new tokens
        await _storeTokens(tokenResponse);
        log("✅ Token refreshed successfully on attempt $attempt");
        return true;
      } catch (e) {
        log("❌ Token refresh attempt $attempt failed: $e");

        if (attempt < _maxRetryAttempts) {
          log("⏳ Retrying in ${_retryDelay.inSeconds} seconds...");
          await Future.delayed(_retryDelay);
        } else {
          log("❌ All token refresh attempts failed");
          return false;
        }
      }
    }

    return false;
  }

  /// Store tokens securely
  Future<void> _storeTokens(TokenResponse tokenResponse) async {
    try {
      // Store tokens in secure storage
      if (tokenResponse.accessToken != null) {
        await _secureStorage.write(
            key: _accessTokenKey, value: tokenResponse.accessToken!);
      }

      if (tokenResponse.refreshToken != null) {
        await _secureStorage.write(
            key: _refreshTokenKey, value: tokenResponse.refreshToken!);
      }

      if (tokenResponse.idToken != null) {
        await _secureStorage.write(
            key: _idTokenKey, value: tokenResponse.idToken!);
      }

      // Store expiry time in GateStorage for compatibility
      if (_gateStorage != null) {
        if (tokenResponse.accessTokenExpirationDateTime != null) {
          await _gateStorage!
              .saveTokenExpiry(tokenResponse.accessTokenExpirationDateTime!);
        } else if (tokenResponse.accessToken != null) {
          // Extract expiry from JWT token
          final expiryTime = JwtTokenUtility.getTokenExpirationTime(
              tokenResponse.accessToken!);
          if (expiryTime != null) {
            await _gateStorage!.saveTokenExpiry(expiryTime);
          } else {
            // Default to 1 hour if no expiry can be determined
            final defaultExpiry = DateTime.now().add(const Duration(hours: 1));
            await _gateStorage!.saveTokenExpiry(defaultExpiry);
          }
        }

        // Store tokens in GateStorage for compatibility
        if (tokenResponse.accessToken != null) {
          await _gateStorage!.saveAccessToken(tokenResponse.accessToken!);
        }
        if (tokenResponse.refreshToken != null) {
          await _gateStorage!.saveRefreshToken(tokenResponse.refreshToken!);
        }
      }

      log("✅ Tokens stored successfully");
    } catch (e) {
      log("❌ Error storing tokens: $e");
      throw Exception('Failed to store tokens: $e');
    }
  }

  /// Check if refresh token is valid
  Future<bool> isRefreshTokenValid() async {
    try {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      if (refreshToken == null) return false;

      // For JWT refresh tokens, check expiration
      if (refreshToken.contains('.')) {
        return JwtTokenUtility.isValidJwtToken(refreshToken);
      }

      // For opaque tokens, we can't validate locally
      return true;
    } catch (e) {
      log("❌ Error validating refresh token: $e");
      return false;
    }
  }

  /// Show current token information
  Future<void> showCurrentTokenInfo() async {
    try {
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      if (accessToken != null) {
        _notificationService.showTokenInfo(accessToken,
            tokenType: "Current Access Token");
      } else {
        _notificationService.showAuthenticationError(
            errorMessage: "No access token available");
      }
    } catch (e) {
      log("❌ Error showing token info: $e");
      _notificationService.showAuthenticationError(
          errorMessage: "Error retrieving token info");
    }
  }

  /// Clear all tokens (logout)
  Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _idTokenKey);

      if (_gateStorage != null) {
        await _gateStorage!.clearTokens();
      }

      stopPeriodicRefreshCheck();
      _notificationService.clearNotifications();
      log("✅ All tokens cleared");
    } catch (e) {
      log("❌ Error clearing tokens: $e");
    }
  }

  /// Dispose resources
  void dispose() {
    stopPeriodicRefreshCheck();
    _refreshCompleter?.complete(false);
    _refreshCompleter = null;
  }
}
