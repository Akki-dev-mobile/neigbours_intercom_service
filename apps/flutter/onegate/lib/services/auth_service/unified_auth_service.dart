import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_onegate/data/datasources/keycloack_config.dart';
import 'package:flutter_onegate/services/auth_service/secure_token_manager.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';

/// Unified authentication service that provides a clean interface for all auth operations
/// This service uses SecureTokenManager for token management and flutter_appauth for OAuth operations
class UnifiedAuthService {
  static final UnifiedAuthService _instance = UnifiedAuthService._internal();
  factory UnifiedAuthService() => _instance;
  UnifiedAuthService._internal();

  // Dependencies
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final SecureTokenManager _tokenManager = SecureTokenManager();
  
  // State management
  bool _isInitialized = false;
  final StreamController<bool> _authStateController = StreamController<bool>.broadcast();

  /// Stream of authentication state changes
  Stream<bool> get authStateStream => _authStateController.stream;

  /// Initialize the authentication service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log('🔐 Initializing UnifiedAuthService...');
      
      await _tokenManager.initialize();
      
      // Check initial authentication state
      final isAuthenticated = await _tokenManager.isAuthenticated();
      _authStateController.add(isAuthenticated);
      
      _isInitialized = true;
      log('✅ UnifiedAuthService initialized successfully');
    } catch (e) {
      log('❌ Error initializing UnifiedAuthService: $e');
      rethrow;
    }
  }

  /// Perform login using flutter_appauth
  Future<Map<String, dynamic>?> login() async {
    try {
      log('🔐 ===== STARTING UNIFIED LOGIN FLOW =====');

      // Display configuration for debugging
      AppAuthConfigManager.logClientConfiguration(includeSecret: true);

      log('🚀 Initiating Authorization and Token Exchange...');

      // Use authorizeAndExchangeCode for automatic PKCE handling
      final AuthorizationTokenResponse result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AppAuthConfigManager.clientId,
          AppAuthConfigManager.redirectUrl,
          serviceConfiguration: AppAuthConfigManager.getServiceConfiguration(),
          scopes: AppAuthConfigManager.scopes,
          clientSecret: AppAuthConfigManager.clientSecret,
          additionalParameters: {
            'access_type': 'offline',
          },
        ),
      );

      if (result.accessToken == null) {
        log("❌ CRITICAL ERROR: No access token received from authorization");
        throw Exception('Login failed - no access token received');
      }

      log("✅ Authorization successful!");
      log("🔑 Access Token: ${result.accessToken!.substring(0, 20)}...");
      log("🔄 Refresh Token: ${result.refreshToken?.substring(0, 20) ?? 'NOT PROVIDED'}...");
      log("🆔 ID Token: ${result.idToken?.substring(0, 20) ?? 'NOT PROVIDED'}...");

      // Store tokens securely using SecureTokenManager
      await _tokenManager.storeTokens(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken,
        idToken: result.idToken,
      );

      // Get user info from Keycloak
      final userInfo = await _getUserInfo(result.accessToken!);

      // Notify authentication state change
      _authStateController.add(true);

      log("✅ ===== LOGIN COMPLETED SUCCESSFULLY =====");
      return userInfo;
    } catch (e) {
      log('❌ ===== LOGIN FAILED =====');
      log('❌ Error Type: ${e.runtimeType}');
      log('❌ Error Message: $e');
      
      _authStateController.add(false);
      rethrow;
    }
  }

  /// Logout user and clear all tokens
  Future<void> logout() async {
    try {
      log('🚪 ===== STARTING LOGOUT =====');

      // Clear tokens from secure storage
      await _tokenManager.clearTokens();

      // Notify authentication state change
      _authStateController.add(false);

      log('✅ ===== LOGOUT COMPLETED =====');
    } catch (e) {
      log('❌ Error during logout: $e');
      rethrow;
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    return await _tokenManager.isAuthenticated();
  }

  /// Get current user information
  Future<Map<String, dynamic>?> getCurrentUser() async {
    return await _tokenManager.getUserInfo();
  }

  /// Get a valid access token (will refresh if needed)
  Future<String?> getValidAccessToken() async {
    return await _tokenManager.getValidAccessToken();
  }

  /// Manually refresh tokens
  Future<bool> refreshTokens() async {
    try {
      final success = await _tokenManager.refreshTokens();
      if (success) {
        _authStateController.add(true);
      }
      return success;
    } catch (e) {
      log('❌ Error refreshing tokens: $e');
      return false;
    }
  }

  /// Get user info from Keycloak userinfo endpoint
  Future<Map<String, dynamic>> _getUserInfo(String accessToken) async {
    try {
      log("👤 Fetching user info from Keycloak...");

      final response = await http.get(
        Uri.parse(AppAuthConfigManager.userInfoEndpoint),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final userInfo = jsonDecode(response.body) as Map<String, dynamic>;
        
        log("✅ User info retrieved successfully");
        log("👤 User: ${userInfo['name'] ?? userInfo['preferred_username']}");
        log("📧 Email: ${userInfo['email']}");
        
        return userInfo;
      } else {
        log("❌ Failed to get user info: ${response.statusCode}");
        log("❌ Response: ${response.body}");
        throw Exception('Failed to get user info: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error getting user info: $e");
      rethrow;
    }
  }

  /// Get user roles from token
  Future<List<String>> getUserRoles() async {
    try {
      final userInfo = await getCurrentUser();
      if (userInfo == null) return [];

      final accessToken = await _tokenManager.getAccessToken();
      if (accessToken == null) return [];

      final tokenInfo = JwtTokenUtility.getUserInfoFromToken(accessToken);
      return List<String>.from(tokenInfo?['roles'] ?? []);
    } catch (e) {
      log('❌ Error getting user roles: $e');
      return [];
    }
  }

  /// Check if user has specific permission/role
  Future<bool> hasRole(String role) async {
    final roles = await getUserRoles();
    return roles.contains(role);
  }

  /// Dispose resources
  void dispose() {
    _tokenManager.dispose();
    _authStateController.close();
    log('🗑️ UnifiedAuthService disposed');
  }
}
