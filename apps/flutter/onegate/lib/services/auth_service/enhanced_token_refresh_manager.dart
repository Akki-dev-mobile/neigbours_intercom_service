import 'dart:async';
import 'dart:developer';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/keycloack_config.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/auth_service/token_notification_service.dart';
import 'package:flutter_onegate/services/auth_service/refresh_token_error_handler.dart';

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
      Duration(seconds: 15); // More frequent for short-lived tokens
  static const int _maxRetryAttempts = 3;

  // Dynamic refresh buffer (calculated per token)
  Duration? _dynamicRefreshBuffer;

  String _tokenPreview(String? token) {
    if (token == null || token.isEmpty) return 'null';
    if (token.length <= 14)
      return '${token.substring(0, token.length)}(len=${token.length})';
    return '${token.substring(0, 8)}...${token.substring(token.length - 6)}(len=${token.length})';
  }

  String _jwtExpiryPreview(String? token) {
    if (token == null || token.isEmpty) return 'none';
    final expiry = JwtTokenUtility.getTokenExpirationTime(token);
    return expiry?.toIso8601String() ?? 'opaque-or-no-exp';
  }

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
  /// Opaque tokens (e.g. old_sso_tokens from hybrid-auth) cannot be refreshed via Keycloak - skip refresh.
  Future<bool> _checkAndRefreshTokenIfNeeded() async {
    try {
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      if (accessToken == null) {
        log("⚠️ No access token found during periodic check");
        return false;
      }

      // Opaque tokens (non-JWT) - cannot refresh via Keycloak, use GateStorage expiry
      if (JwtTokenUtility.getTokenExpirationTime(accessToken) == null) {
        final gateStorage = _gateStorage ?? GateStorage();
        final isExpired = await gateStorage.isTokenExpired();
        if (isExpired) {
          log("⚠️ Opaque token expired - cannot refresh via Keycloak");
          return false;
        }
        log("✅ Opaque token valid (per stored expiry) - skipping Keycloak refresh");
        return true;
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
  /// Falls back to GateStorage when secure storage is empty (e.g. app kill cleared FlutterSecureStorage)
  Future<String?> getValidAccessToken() async {
    try {
      var accessToken = await _secureStorage.read(key: _accessTokenKey);

      // Fallback: GateStorage persists across app kill (SharedPreferences survives).
      // Even if the access token is expired, we migrate both tokens into secure storage
      // so the refresh logic below can use the refresh token to get a new access token.
      if (accessToken == null) {
        final gateStorage = _gateStorage ?? GateStorage();
        final gatAccessToken = await gateStorage.getAccessToken();
        final gatRefreshToken = await gateStorage.getRefreshToken();

        if (gatAccessToken != null &&
            gatAccessToken.isNotEmpty &&
            gatRefreshToken != null &&
            gatRefreshToken.isNotEmpty &&
            JwtTokenUtility.parseJwtToken(gatAccessToken) != null) {
          // Access token is a valid JWT structure (may be expired – refresh handles that)
          log("🔄 Migrating tokens from GateStorage to secure storage (persistence recovery)");
          await _secureStorage.write(
              key: _accessTokenKey, value: gatAccessToken);
          await _secureStorage.write(
              key: _refreshTokenKey, value: gatRefreshToken);
          accessToken = gatAccessToken;
        } else if (gatRefreshToken != null && gatRefreshToken.isNotEmpty) {
          // We have a refresh token but no usable access token – store refresh token
          // and attempt a refresh below which will produce a new access token.
          log("🔄 No valid access token in GateStorage but refresh token present – migrating refresh token");
          await _secureStorage.write(
              key: _refreshTokenKey, value: gatRefreshToken);
          // Force expiry path by keeping accessToken null so refresh is triggered
        } else {
          log("❌ GateStorage has no usable tokens");
        }
      }

      if (accessToken == null) {
        // No access token, but check if we have a refresh token to recover the session
        final storedRefresh = await _secureStorage.read(key: _refreshTokenKey);
        if (storedRefresh != null && storedRefresh.isNotEmpty) {
          log("🔄 No access token but refresh token present – attempting session recovery");
          final refreshed = await refreshTokenIfNeeded();
          if (refreshed) {
            return await _secureStorage.read(key: _accessTokenKey);
          }
        }
        log("❌ No access token and refresh failed or no refresh token");
        return null;
      }

      // Opaque tokens (non-JWT) - cannot refresh via Keycloak
      if (JwtTokenUtility.getTokenExpirationTime(accessToken) == null) {
        final gateStorage = _gateStorage ?? GateStorage();
        final isExpired = await gateStorage.isTokenExpired();
        if (!isExpired) {
          log("✅ Opaque token valid - returning without refresh");
          return accessToken;
        }
        log("⚠️ Opaque token expired - cannot refresh via Keycloak");
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

  /// Perform the actual token refresh with enhanced error handling
  Future<bool> _performTokenRefresh() async {
    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        log("🔄 Token refresh attempt $attempt/$_maxRetryAttempts");

        final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
        if (refreshToken == null) {
          log("❌ No refresh token available");
          await _handleRefreshTokenFailure(
            const RefreshTokenException('No refresh token available'),
            attempt,
            RefreshTokenFailureType.missingRefreshToken,
          );
          return false;
        }

        log(
          "🔍 [REFRESH-DIAG] BEFORE request: "
          "refresh=${_tokenPreview(refreshToken)} "
          "refreshExp=${_jwtExpiryPreview(refreshToken)}",
        );

        // Use flutter_appauth for token refresh
        final tokenResponse = await _appAuth.token(
          AppAuthConfigManager.getRefreshTokenRequest(refreshToken),
        );
        final dynamic additionalParams =
            (tokenResponse as dynamic).tokenAdditionalParameters;
        final dynamic refreshExpiresIn = additionalParams is Map
            ? additionalParams['refresh_expires_in']
            : null;

        log(
          "🔍 [REFRESH-DIAG] RESPONSE: "
          "hasAccess=${tokenResponse.accessToken != null} "
          "hasRefresh=${tokenResponse.refreshToken != null} "
          "accessExp=${tokenResponse.accessTokenExpirationDateTime?.toIso8601String() ?? 'null'} "
          "refresh_expires_in=${refreshExpiresIn ?? 'not-provided'}",
        );

        if (tokenResponse.accessToken == null) {
          log("❌ Token refresh failed - no access token received");
          await _handleRefreshTokenFailure(
            const RefreshTokenException('No access token received'),
            attempt,
            RefreshTokenFailureType.invalidResponse,
          );

          if (attempt < _maxRetryAttempts) {
            final delay = _calculateBackoffDelay(attempt);
            log("⏳ Retrying in ${delay.inSeconds} seconds...");
            await Future.delayed(delay);
            continue;
          }
          return false;
        }

        // Store new tokens
        await _storeTokens(tokenResponse);
        log("✅ Token refreshed successfully on attempt $attempt");

        // Reset failure counters on success
        await _resetRefreshFailureCounters();
        return true;
      } catch (e) {
        log("❌ Token refresh attempt $attempt failed: $e");
        final failureType = _analyzeRefreshFailure(e);
        log("🔍 [REFRESH-DIAG] FAILURE CLASSIFICATION: $failureType");

        // Analyze and handle the specific failure
        await _handleRefreshTokenFailure(e, attempt, failureType);

        if (attempt < _maxRetryAttempts && _shouldRetryFailure(failureType)) {
          final delay = _calculateBackoffDelay(attempt);
          log("⏳ Retrying in ${delay.inSeconds} seconds...");
          await Future.delayed(delay);
        } else {
          log("❌ All token refresh attempts failed or failure is non-retryable");
          return false;
        }
      }
    }

    return false;
  }

  /// Store tokens securely with dynamic duration calculation based on JWT iat/exp
  Future<void> _storeTokens(TokenResponse tokenResponse) async {
    try {
      log("💾 Storing tokens with dynamic duration calculation...");
      final previousSecureRefresh =
          await _secureStorage.read(key: _refreshTokenKey);
      final previousGateRefresh = await _gateStorage?.getRefreshToken();
      log(
        "🔍 [REFRESH-DIAG] BEFORE save: "
        "secureRefresh=${_tokenPreview(previousSecureRefresh)} "
        "gateRefresh=${_tokenPreview(previousGateRefresh)}",
      );

      // Store access token and analyze its duration
      if (tokenResponse.accessToken != null) {
        await _secureStorage.write(
            key: _accessTokenKey, value: tokenResponse.accessToken!);

        // Log detailed token analysis
        JwtTokenUtility.logTokenDetails("ACCESS", tokenResponse.accessToken!);

        // Calculate actual token duration from JWT claims
        final tokenAnalysis =
            JwtTokenUtility.getTokenAnalysis(tokenResponse.accessToken!);
        log("📊 Access Token Duration Analysis:");
        log("   • Lifespan: ${tokenAnalysis['lifespanMinutes']} minutes");
        log("   • Refresh Buffer: ${tokenAnalysis['refreshBuffer']} minutes");
        log("   • Should Refresh Now: ${tokenAnalysis['shouldRefreshNow']}");
      }

      // Store refresh token and analyze if it's a JWT
      if (tokenResponse.refreshToken != null) {
        await _secureStorage.write(
            key: _refreshTokenKey, value: tokenResponse.refreshToken!);

        // Check if refresh token is also a JWT and log its details
        if (JwtTokenUtility.isValidJwtToken(tokenResponse.refreshToken!)) {
          JwtTokenUtility.logTokenDetails(
              "REFRESH", tokenResponse.refreshToken!);
          log("🔄 Refresh token is JWT - analyzing duration...");
        } else {
          log("🔄 Refresh token is opaque (non-JWT)");
        }
      }

      if (tokenResponse.idToken != null) {
        await _secureStorage.write(
            key: _idTokenKey, value: tokenResponse.idToken!);
      }

      // Store expiry time in GateStorage using JWT-based calculation (not hardcoded)
      if (_gateStorage != null && tokenResponse.accessToken != null) {
        // Always extract expiry from JWT token for accuracy
        final expiryTime =
            JwtTokenUtility.getTokenExpirationTime(tokenResponse.accessToken!);
        final issuedTime =
            JwtTokenUtility.getTokenIssuedAtTime(tokenResponse.accessToken!);

        if (expiryTime != null && issuedTime != null) {
          await _gateStorage!.saveTokenExpiry(expiryTime);

          // Calculate and log actual token duration from JWT claims
          final actualDuration = expiryTime.difference(issuedTime);
          log("⏱️ JWT-based Token Duration:");
          log("   • Issued At (iat): ${issuedTime.toIso8601String()}");
          log("   • Expires At (exp): ${expiryTime.toIso8601String()}");
          log("   • Actual Duration: ${actualDuration.inMinutes}min ${actualDuration.inSeconds % 60}s");

          // Compare with server-provided expiry if available
          if (tokenResponse.accessTokenExpirationDateTime != null) {
            final serverExpiry = tokenResponse.accessTokenExpirationDateTime!;
            final timeDiff = expiryTime.difference(serverExpiry).abs();
            log("   • Server vs JWT expiry diff: ${timeDiff.inSeconds}s");
          }
        } else {
          // Fallback to server-provided expiry
          if (tokenResponse.accessTokenExpirationDateTime != null) {
            await _gateStorage!
                .saveTokenExpiry(tokenResponse.accessTokenExpirationDateTime!);
            log("⚠️ Using server-provided expiry (JWT parsing failed)");
          } else {
            // Conservative fallback based on common token patterns
            final now = DateTime.now();
            final conservativeExpiry = now.add(const Duration(minutes: 5));
            await _gateStorage!.saveTokenExpiry(conservativeExpiry);
            log("⚠️ Using conservative 5-minute expiry (no expiry info available)");
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

      log("✅ Tokens stored successfully with JWT-based duration calculation");

      final currentSecureRefresh =
          await _secureStorage.read(key: _refreshTokenKey);
      final currentGateRefresh = await _gateStorage?.getRefreshToken();
      final serverRefresh = tokenResponse.refreshToken;
      final rotated = serverRefresh != null &&
          previousSecureRefresh != null &&
          serverRefresh != previousSecureRefresh;
      log(
        "🔍 [REFRESH-DIAG] AFTER save: "
        "serverRefresh=${_tokenPreview(serverRefresh)} "
        "secureRefresh=${_tokenPreview(currentSecureRefresh)} "
        "gateRefresh=${_tokenPreview(currentGateRefresh)} "
        "rotated=$rotated "
        "refreshExp(server)=${_jwtExpiryPreview(serverRefresh)}",
      );
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

  /// Analyze refresh failure type
  RefreshTokenFailureType _analyzeRefreshFailure(dynamic error) {
    return RefreshTokenErrorHandler.analyzeFailure(error);
  }

  /// Check if failure should be retried
  bool _shouldRetryFailure(RefreshTokenFailureType failureType) {
    return RefreshTokenErrorHandler.shouldRetryFailure(failureType);
  }

  /// Calculate exponential backoff delay
  Duration _calculateBackoffDelay(int attemptNumber) {
    return RefreshTokenErrorHandler.calculateBackoffDelay(attemptNumber);
  }

  /// Handle refresh token failure
  Future<void> _handleRefreshTokenFailure(
    dynamic error,
    int attemptNumber,
    RefreshTokenFailureType failureType,
  ) async {
    await RefreshTokenErrorHandler.handleRefreshTokenFailure(
      error,
      attemptNumber,
      failureType,
    );
  }

  /// Reset refresh failure counters
  Future<void> _resetRefreshFailureCounters() async {
    RefreshTokenErrorHandler.resetFailureCounters();
  }

  /// Get refresh failure statistics
  Map<String, dynamic> getRefreshFailureStatistics() {
    return RefreshTokenErrorHandler.getFailureStatistics();
  }

  /// Dispose resources
  void dispose() {
    stopPeriodicRefreshCheck();
    _refreshCompleter?.complete(false);
    _refreshCompleter = null;
  }
}
