import 'dart:async';
import 'dart:developer';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_onegate/data/datasources/keycloack_config.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';

/// Secure token manager that handles JWT-based token refresh with flutter_appauth
/// This is the unified solution for session expiry and secure token management
class SecureTokenManager {
  static final SecureTokenManager _instance = SecureTokenManager._internal();
  factory SecureTokenManager() => _instance;
  SecureTokenManager._internal();

  // Dependencies
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Storage keys
  static const String _accessTokenKey = 'secure_access_token';
  static const String _refreshTokenKey = 'secure_refresh_token';
  static const String _idTokenKey = 'secure_id_token';

  // State management
  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;
  Timer? _refreshTimer;

  // Token refresh buffer (refresh 2 minutes before expiry)
  static const Duration _refreshBuffer = Duration(minutes: 2);

  /// Initialize the token manager
  Future<void> initialize() async {
    try {
      log('🔐 Initializing SecureTokenManager...');

      // Check if we have valid tokens and schedule refresh if needed
      final accessToken = await getAccessToken();
      if (accessToken != null) {
        await _scheduleTokenRefresh(accessToken);
      }

      log('✅ SecureTokenManager initialized successfully');
    } catch (e) {
      log('❌ Error initializing SecureTokenManager: $e');
    }
  }

  /// Store tokens securely
  Future<void> storeTokens({
    required String accessToken,
    String? refreshToken,
    String? idToken,
  }) async {
    try {
      log('💾 Storing tokens securely...');

      await _secureStorage.write(key: _accessTokenKey, value: accessToken);

      if (refreshToken != null) {
        await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
      }

      if (idToken != null) {
        await _secureStorage.write(key: _idTokenKey, value: idToken);
      }

      // Schedule automatic refresh based on JWT expiry
      await _scheduleTokenRefresh(accessToken);

      log('✅ Tokens stored and refresh scheduled');
    } catch (e) {
      log('❌ Error storing tokens: $e');
      rethrow;
    }
  }

  /// Get access token from secure storage
  Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: _accessTokenKey);
    } catch (e) {
      log('❌ Error reading access token: $e');
      return null;
    }
  }

  /// Get refresh token from secure storage
  Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: _refreshTokenKey);
    } catch (e) {
      log('❌ Error reading refresh token: $e');
      return null;
    }
  }

  /// Get ID token from secure storage
  Future<String?> getIdToken() async {
    try {
      return await _secureStorage.read(key: _idTokenKey);
    } catch (e) {
      log('❌ Error reading ID token: $e');
      return null;
    }
  }

  /// Get a valid access token, refreshing if necessary
  Future<String?> getValidAccessToken() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) {
        log('⚠️ No access token available');
        return null;
      }

      // Check if token is valid and not expired/expiring
      if (JwtTokenUtility.isValidJwtToken(accessToken) &&
          !JwtTokenUtility.isTokenExpiredOrExpiring(accessToken,
              buffer: _refreshBuffer)) {
        return accessToken;
      }

      log('🔄 Access token expired or expiring, attempting refresh...');

      // Token is expired or expiring, try to refresh
      final refreshed = await refreshTokens();
      if (refreshed) {
        return await getAccessToken();
      }

      log('❌ Token refresh failed');
      return null;
    } catch (e) {
      log('❌ Error getting valid access token: $e');
      return null;
    }
  }

  /// Refresh tokens using flutter_appauth
  Future<bool> refreshTokens() async {
    // Prevent concurrent refresh attempts
    if (_isRefreshing) {
      log('🔄 Token refresh already in progress, waiting...');
      return await (_refreshCompleter?.future ?? Future.value(false));
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      log('🔄 Starting token refresh...');

      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        log('❌ No refresh token available');
        _refreshCompleter!.complete(false);
        return false;
      }

      // Use flutter_appauth to refresh tokens
      final tokenResponse = await _appAuth.token(
        AppAuthConfigManager.getRefreshTokenRequest(refreshToken),
      );

      if (tokenResponse.accessToken == null) {
        log('❌ Token refresh failed - no access token received');
        _refreshCompleter!.complete(false);
        return false;
      }

      // Store the new tokens
      await storeTokens(
        accessToken: tokenResponse.accessToken!,
        refreshToken: tokenResponse.refreshToken ??
            refreshToken, // Keep old refresh token if new one not provided
        idToken: tokenResponse.idToken,
      );

      log('✅ Token refresh successful');
      _refreshCompleter!.complete(true);
      return true;
    } catch (e) {
      log('❌ Token refresh failed: $e');
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  /// Schedule automatic token refresh based on JWT expiry
  Future<void> _scheduleTokenRefresh(String accessToken) async {
    try {
      // Cancel any existing timer
      _refreshTimer?.cancel();

      // Get token expiration time
      final expirationTime =
          JwtTokenUtility.getTokenExpirationTime(accessToken);
      if (expirationTime == null) {
        log('⚠️ Cannot determine token expiration, scheduling fallback refresh');
        _refreshTimer =
            Timer(const Duration(minutes: 3), () => refreshTokens());
        return;
      }

      // Calculate when to refresh (buffer time before expiry)
      final now = DateTime.now();
      final refreshTime = expirationTime.subtract(_refreshBuffer);

      if (refreshTime.isBefore(now)) {
        // Token expires very soon, refresh immediately
        log('🚨 Token expires very soon, refreshing immediately');
        refreshTokens();
        return;
      }

      final timeUntilRefresh = refreshTime.difference(now);
      log('⏰ Scheduling token refresh in ${timeUntilRefresh.inMinutes} minutes (${_refreshBuffer.inMinutes}min before expiry)');

      _refreshTimer = Timer(timeUntilRefresh, () {
        log('⏰ Automatic token refresh triggered');
        refreshTokens();
      });
    } catch (e) {
      log('❌ Error scheduling token refresh: $e');
      // Fallback: schedule refresh in 3 minutes
      _refreshTimer = Timer(const Duration(minutes: 3), () => refreshTokens());
    }
  }

  /// Clear all stored tokens
  Future<void> clearTokens() async {
    try {
      log('🗑️ Clearing all stored tokens...');

      _refreshTimer?.cancel();
      _refreshTimer = null;

      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _idTokenKey);

      log('✅ All tokens cleared');
    } catch (e) {
      log('❌ Error clearing tokens: $e');
    }
  }

  /// Check if user is authenticated (has valid tokens)
  Future<bool> isAuthenticated() async {
    try {
      final accessToken = await getAccessToken();
      final refreshToken = await getRefreshToken();

      if (accessToken == null || refreshToken == null) {
        return false;
      }

      // Check if access token is valid
      if (JwtTokenUtility.isValidJwtToken(accessToken)) {
        return true;
      }

      // Access token invalid, check if refresh token is valid
      if (JwtTokenUtility.isValidJwtToken(refreshToken)) {
        // Try to refresh
        return await refreshTokens();
      }

      return false;
    } catch (e) {
      log('❌ Error checking authentication: $e');
      return false;
    }
  }

  /// Get user information from the current access token
  Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final accessToken = await getValidAccessToken();
      if (accessToken == null) {
        return null;
      }

      return JwtTokenUtility.getUserInfoFromToken(accessToken);
    } catch (e) {
      log('❌ Error getting user info: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _refreshCompleter = null;
    log('🗑️ SecureTokenManager disposed');
  }
}
