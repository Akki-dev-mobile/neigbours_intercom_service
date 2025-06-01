import 'dart:async';
import 'dart:developer';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/datasources/keycloack_config.dart';
import '../jwt_token_utility.dart';
import 'auth_tokens.dart';
import 'auth_storage.dart';
import 'auth_state.dart';

part 'auth_controller.g.dart';

/// Riverpod provider for AuthController
@riverpod
class AuthController extends _$AuthController {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final AuthStorage _storage = AuthStorage();

  Timer? _refreshTimer;
  bool _isRefreshing = false;

  @override
  AuthState build() {
    // Initialize from storage when the provider is first created
    _initializeFromStorage();
    return const AuthState.unauthenticated();
  }

  /// Initialize authentication state from secure storage
  Future<void> _initializeFromStorage() async {
    try {
      log('🔄 Initializing auth state from storage...');

      final tokens = await _storage.getTokens();
      if (tokens == null || !tokens.isValid) {
        log('ℹ️ No valid tokens found in storage');
        state = const AuthState.unauthenticated();
        return;
      }

      final userInfo = await _storage.getUserInfo();
      if (userInfo == null) {
        log('⚠️ Tokens found but no user info, clearing tokens');
        await _storage.clearAll();
        state = const AuthState.unauthenticated();
        return;
      }

      // Check if tokens need refresh
      if (tokens.willExpireWithin(const Duration(minutes: 5))) {
        log('🔄 Tokens expiring soon, attempting refresh...');
        final refreshed = await _performTokenRefresh(tokens.refreshToken);
        if (!refreshed) {
          log('❌ Token refresh failed during initialization');
          await logout();
          return;
        }
      } else {
        // Tokens are valid, set authenticated state
        state = AuthState.authenticated(tokens: tokens, userInfo: userInfo);
        _scheduleTokenRefresh(tokens);
      }

      log('✅ Auth state initialized successfully');
    } catch (e) {
      log('❌ Error initializing auth state: $e');
      state = const AuthState.unauthenticated();
    }
  }

  /// Perform login using flutter_appauth
  Future<bool> login() async {
    try {
      log('🔐 Starting login process...');
      state = const AuthState.loading();

      // Perform authorization and token exchange
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AppAuthConfigManager.clientId,
          AppAuthConfigManager.redirectUrl,
          serviceConfiguration: AppAuthConfigManager.getServiceConfiguration(),
          scopes: AppAuthConfigManager.scopes,
          clientSecret: AppAuthConfigManager.clientSecret,
          additionalParameters: {'access_type': 'offline'},
        ),
      );

      if (result.accessToken == null ||
          result.refreshToken == null ||
          result.accessTokenExpirationDateTime == null) {
        throw Exception('Incomplete token response from authorization server');
      }

      // Create tokens object
      final tokens = AuthTokens.fromAuthResponse(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken!,
        idToken: result.idToken ?? '',
        accessTokenExpirationDateTime: result.accessTokenExpirationDateTime!,
      );

      // Get user info from Keycloak
      final userInfo = await _getUserInfo(tokens.accessToken);

      // Store tokens and user info
      await _storage.storeTokens(tokens);
      await _storage.storeUserInfo(userInfo);

      // Update state
      state = AuthState.authenticated(tokens: tokens, userInfo: userInfo);

      // Schedule automatic refresh
      _scheduleTokenRefresh(tokens);

      log('✅ Login completed successfully');
      return true;
    } catch (e) {
      log('❌ Login failed: $e');
      state = AuthState.error(message: 'Login failed: $e');
      return false;
    }
  }

  /// Perform logout
  Future<void> logout() async {
    try {
      log('🚪 Starting logout process...');

      // Cancel refresh timer
      _refreshTimer?.cancel();
      _refreshTimer = null;

      // Clear stored data
      await _storage.clearAll();

      // Update state
      state = const AuthState.unauthenticated();

      log('✅ Logout completed successfully');
    } catch (e) {
      log('❌ Error during logout: $e');
      // Even if there's an error, ensure we're in unauthenticated state
      state = const AuthState.unauthenticated();
    }
  }

  /// Refresh access token using refresh token
  Future<bool> refreshToken() async {
    if (_isRefreshing) {
      log('🔄 Token refresh already in progress, waiting...');
      // Wait for current refresh to complete
      while (_isRefreshing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return state.maybeWhen(
        authenticated: (_, __) => true,
        orElse: () => false,
      );
    }

    return state.maybeWhen(
      authenticated: (tokens, userInfo) async {
        return await _performTokenRefresh(tokens.refreshToken);
      },
      orElse: () async {
        log('⚠️ Cannot refresh token: not authenticated');
        return false;
      },
    );
  }

  /// Internal method to perform token refresh
  Future<bool> _performTokenRefresh(String refreshToken) async {
    if (_isRefreshing) return false;

    _isRefreshing = true;
    try {
      log('🔄 Refreshing access token...');

      final tokenRequest =
          AppAuthConfigManager.getRefreshTokenRequest(refreshToken);
      final result = await _appAuth.token(tokenRequest);

      if (result.accessToken == null ||
          result.accessTokenExpirationDateTime == null) {
        throw Exception('Invalid token refresh response');
      }

      // Create updated tokens
      final currentState = state;
      if (currentState is! AuthenticatedState) {
        throw Exception('Cannot refresh token: not in authenticated state');
      }

      // Calculate expiry time from JWT claims for accuracy
      DateTime expiresAt;
      if (result.accessTokenExpirationDateTime != null) {
        expiresAt = result.accessTokenExpirationDateTime!;
      } else {
        // Extract expiry from JWT token
        final jwtExpiryTime =
            JwtTokenUtility.getTokenExpirationTime(result.accessToken!);
        if (jwtExpiryTime != null) {
          expiresAt = jwtExpiryTime;
          log('🔍 Using JWT-extracted expiry time: ${expiresAt.toIso8601String()}');
        } else {
          // Conservative fallback
          expiresAt = DateTime.now().add(const Duration(minutes: 5));
          log('⚠️ Using conservative 5-minute expiry (no expiry info available)');
        }
      }

      // Log token duration analysis
      final issuedTime =
          JwtTokenUtility.getTokenIssuedAtTime(result.accessToken!);
      if (issuedTime != null) {
        final actualDuration = expiresAt.difference(issuedTime);
        log('⏱️ Riverpod Token Duration Analysis:');
        log('   • Issued At (iat): ${issuedTime.toIso8601String()}');
        log('   • Expires At (exp): ${expiresAt.toIso8601String()}');
        log('   • Calculated Duration: ${actualDuration.inMinutes}min ${actualDuration.inSeconds % 60}s');
      }

      // Update tokens - use new refresh token if provided, otherwise keep existing
      final updatedRefreshToken =
          result.refreshToken ?? currentState.tokens.refreshToken;

      final updatedTokens = currentState.tokens.copyWith(
        accessToken: result.accessToken!,
        expiresAt: expiresAt,
        idToken: result.idToken ?? currentState.tokens.idToken,
        refreshToken: updatedRefreshToken,
      );

      // Log refresh token update status
      if (result.refreshToken != null) {
        log('🔄 Refresh token updated with new token from server');
      } else {
        log('🔄 Refresh token preserved (server did not provide new refresh token)');
      }

      // Store updated tokens
      await _storage.storeTokens(updatedTokens);

      // Update state
      state = AuthState.authenticated(
        tokens: updatedTokens,
        userInfo: currentState.userInfo,
      );

      // Schedule next refresh
      _scheduleTokenRefresh(updatedTokens);

      log('✅ Token refreshed successfully');
      return true;
    } catch (e) {
      log('❌ Token refresh failed: $e');

      // If refresh fails, logout user
      await logout();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Schedule automatic token refresh
  void _scheduleTokenRefresh(AuthTokens tokens) {
    _refreshTimer?.cancel();

    final timeUntilExpiry = tokens.timeUntilExpiration;
    if (timeUntilExpiry == null) {
      log('⚠️ Cannot determine token expiry, scheduling immediate refresh');
      Timer(const Duration(seconds: 30), () => refreshToken());
      return;
    }

    Duration refreshBuffer;
    Duration refreshTime;

    // Calculate refresh timing based on token lifespan
    if (timeUntilExpiry.inMinutes <= 5) {
      // For 5-minute or shorter tokens, refresh at 60% of lifespan (e.g., 3 minutes for 5-minute token)
      refreshBuffer =
          Duration(seconds: (timeUntilExpiry.inSeconds * 0.4).round());
      refreshTime = timeUntilExpiry - refreshBuffer;

      // Ensure minimum refresh time of 30 seconds
      if (refreshTime.inSeconds < 30) {
        refreshTime = const Duration(seconds: 30);
      }

      log('⏰ Short token (${timeUntilExpiry.inMinutes}min) - scheduling refresh in ${refreshTime.inMinutes}min ${refreshTime.inSeconds % 60}s');
    } else if (timeUntilExpiry.inMinutes <= 15) {
      // For 6-15 minute tokens, use 2-minute buffer
      refreshBuffer = const Duration(minutes: 2);
      refreshTime = timeUntilExpiry - refreshBuffer;
      log('⏰ Medium token (${timeUntilExpiry.inMinutes}min) - scheduling refresh in ${refreshTime.inMinutes} minutes');
    } else {
      // For longer tokens, use 2-minute buffer
      refreshBuffer = const Duration(minutes: 2);
      refreshTime = timeUntilExpiry - refreshBuffer;
      log('⏰ Long token (${timeUntilExpiry.inMinutes}min) - scheduling refresh in ${refreshTime.inMinutes} minutes');
    }

    // Schedule the refresh
    _refreshTimer = Timer(refreshTime, () {
      log('⏰ Automatic token refresh triggered (${refreshBuffer.inMinutes}min before expiry)');
      refreshToken();
    });
  }

  /// Get user info from Keycloak userinfo endpoint
  Future<Map<String, dynamic>> _getUserInfo(String accessToken) async {
    // This would typically make an HTTP request to the userinfo endpoint
    // For now, we'll return a placeholder implementation
    // You should implement this based on your Keycloak setup

    log('👤 Getting user info from Keycloak...');

    // TODO: Implement actual HTTP request to userinfo endpoint
    // Example implementation would be:
    // final response = await http.get(
    //   Uri.parse(AppAuthConfigManager.userInfoEndpoint),
    //   headers: {'Authorization': 'Bearer $accessToken'},
    // );

    return {
      'sub': 'user-id',
      'email': 'user@example.com',
      'name': 'User Name',
      'preferred_username': 'username',
    };
  }

  /// Get current access token (for API calls)
  String? get accessToken {
    return state.maybeWhen(
      authenticated: (tokens, _) => tokens.accessToken,
      orElse: () => null,
    );
  }

  /// Check if user is authenticated
  bool get isAuthenticated {
    return state.maybeWhen(
      authenticated: (_, __) => true,
      orElse: () => false,
    );
  }

  /// Dispose resources
  void dispose() {
    _refreshTimer?.cancel();
  }
}
