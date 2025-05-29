import 'dart:convert';
import 'dart:developer';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/datasources/enhanced_keycloak_config.dart';

/// Enhanced AuthService with multiple authentication strategies and comprehensive error handling
class EnhancedAuthService {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final GateStorage gateStorage;
  final RemoteDataSource remoteDataSource;

  // Storage keys for secure storage
  static const String _accessTokenKey = 'access_token_secure';
  static const String _refreshTokenKey = 'refresh_token_secure';
  static const String _idTokenKey = 'id_token_secure';

  EnhancedAuthService({
    required this.gateStorage,
    required this.remoteDataSource,
  });

  /// Initialize the enhanced auth service
  Future<void> initialize() async {
    try {
      log("🔧 Initializing Enhanced Auth Service...");

      // Print comprehensive configuration report
      EnhancedKeycloakConfig.printConfigurationReport();

      // Test endpoint connectivity
      log("🌐 Testing endpoint connectivity...");
      final connectivity =
          await EnhancedKeycloakConfig.testEndpointConnectivity();

      log("📡 Connectivity Results:");
      connectivity.forEach((endpoint, isReachable) {
        log("   • $endpoint: ${isReachable ? '✅ Reachable' : '❌ Unreachable'}");
      });

      final unreachableEndpoints = connectivity.entries
          .where((entry) => !entry.value)
          .map((entry) => entry.key)
          .toList();

      if (unreachableEndpoints.isNotEmpty) {
        log("⚠️ Warning: Some endpoints are unreachable: ${unreachableEndpoints.join(', ')}");
      }

      log("✅ Enhanced Auth Service initialized successfully");
    } catch (e) {
      log('❌ Error initializing Enhanced Auth Service: $e');
      throw Exception('Failed to initialize Enhanced Auth Service: $e');
    }
  }

  /// Enhanced login with multiple strategies
  Future<Map<String, dynamic>?> login() async {
    try {
      log('🔐 ===== STARTING ENHANCED AUTHENTICATION FLOW =====');

      // Strategy 1: Try confidential client authentication
      if (EnhancedKeycloakConfig.isConfidentialClient) {
        log('🔐 Attempting CONFIDENTIAL client authentication...');
        try {
          final result = await _attemptConfidentialClientAuth();
          if (result != null) {
            return await _processAuthenticationResult(result);
          }
        } catch (e) {
          log('❌ Confidential client auth failed: $e');
          log('🔄 Falling back to public client authentication...');
        }
      }

      // Strategy 2: Try public client authentication
      log('🔓 Attempting PUBLIC client authentication...');
      try {
        final result = await _attemptPublicClientAuth();
        if (result != null) {
          return await _processAuthenticationResult(result);
        }
      } catch (e) {
        log('❌ Public client auth failed: $e');
      }

      throw Exception('All authentication strategies failed');
    } catch (e) {
      log('❌ ===== ENHANCED AUTHENTICATION FAILED =====');
      log('❌ Error Type: ${e.runtimeType}');
      log('❌ Error Message: $e');
      _logTroubleshootingGuide(e);
      throw Exception('Enhanced authentication failed: $e');
    }
  }

  /// Attempt confidential client authentication
  Future<AuthorizationTokenResponse?> _attemptConfidentialClientAuth() async {
    log('🔐 Executing confidential client authentication...');

    final request = EnhancedKeycloakConfig.createConfidentialClientRequest();

    final result = await _appAuth.authorizeAndExchangeCode(request);

    if (result.accessToken != null) {
      log('✅ Confidential client authentication successful');
      return result;
    }

    return null;
  }

  /// Attempt public client authentication
  Future<AuthorizationTokenResponse?> _attemptPublicClientAuth() async {
    log('🔓 Executing public client authentication...');

    final request = EnhancedKeycloakConfig.createPublicClientRequest();

    final result = await _appAuth.authorizeAndExchangeCode(request);

    if (result.accessToken != null) {
      log('✅ Public client authentication successful');
      return result;
    }

    return null;
  }

  /// Process authentication result
  Future<Map<String, dynamic>?> _processAuthenticationResult(
      AuthorizationTokenResponse result) async {
    log("✅ ===== AUTHENTICATION SUCCESSFUL =====");
    log("🔑 Access Token: ${result.accessToken!.substring(0, 20)}... (${result.accessToken!.length} chars)");
    log("🔄 Refresh Token: ${result.refreshToken != null ? 'Present' : 'Not provided'}");
    log("🆔 ID Token: ${result.idToken != null ? 'Present' : 'Not provided'}");
    log("⏰ Token Expiry: ${result.accessTokenExpirationDateTime ?? 'Not specified'}");

    // Store tokens securely
    log("💾 Storing tokens securely...");
    await _storeTokensFromAuthResponse(result);

    // Get user info from Keycloak
    log("👤 Fetching user info from Keycloak...");
    final userInfo = await _getUserInfo(result.accessToken!);

    // Save user data to local storage
    log("💾 Saving user data to local storage...");
    await _saveUserData(userInfo);

    log("✅ ===== AUTHENTICATION COMPLETED SUCCESSFULLY =====");
    return userInfo;
  }

  /// Store tokens securely from AuthorizationTokenResponse
  Future<void> _storeTokensFromAuthResponse(
      AuthorizationTokenResponse authResponse) async {
    try {
      // Store in secure storage
      if (authResponse.accessToken != null) {
        await _secureStorage.write(
            key: _accessTokenKey, value: authResponse.accessToken!);
        await gateStorage.saveAccessToken(authResponse.accessToken!);
      }

      if (authResponse.refreshToken != null) {
        await _secureStorage.write(
            key: _refreshTokenKey, value: authResponse.refreshToken!);
        await gateStorage.saveRefreshToken(authResponse.refreshToken!);
      }

      if (authResponse.idToken != null) {
        await _secureStorage.write(
            key: _idTokenKey, value: authResponse.idToken!);
      }

      // Calculate and save token expiry
      if (authResponse.accessTokenExpirationDateTime != null) {
        await gateStorage
            .saveTokenExpiry(authResponse.accessTokenExpirationDateTime!);
      } else {
        // Default to 1 hour if no expiry provided
        final expiryTime = DateTime.now().add(const Duration(hours: 1));
        await gateStorage.saveTokenExpiry(expiryTime);
      }

      log("✅ Tokens stored successfully");
    } catch (e) {
      log("❌ Error storing tokens: $e");
      throw Exception('Failed to store tokens: $e');
    }
  }

  /// Get user info from Keycloak userinfo endpoint
  Future<Map<String, dynamic>> _getUserInfo(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse(EnhancedKeycloakConfig.userInfoEndpoint),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final userInfo = jsonDecode(response.body) as Map<String, dynamic>;
        log("✅ User info retrieved successfully");
        return userInfo;
      } else {
        throw Exception(
            'Failed to get user info: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      log("❌ Error getting user info: $e");
      throw Exception('Failed to get user info: $e');
    }
  }

  /// Save user data to local storage
  Future<void> _saveUserData(Map<String, dynamic>? userInfo) async {
    if (userInfo == null) return;

    try {
      // Save basic user information
      await gateStorage
          .saveUserId(userInfo["sub"] ?? userInfo["old_sso_user_id"] ?? "");
      await gateStorage.saveUsername(
          userInfo["preferred_username"] ?? userInfo["username"] ?? "");

      // Save additional user session data
      if (userInfo["email"] != null) {
        await gateStorage.saveUserEmail(userInfo["email"]);
      }

      if (userInfo["name"] != null) {
        await gateStorage.saveUserFullName(userInfo["name"]);
      }

      // Extract and save user roles
      final roles = _extractUserRoles(userInfo);
      if (roles.isNotEmpty) {
        await gateStorage.saveUserRoles(roles);
      }

      // Save session timestamp
      await gateStorage.saveSessionTimestamp(DateTime.now());

      log("✅ Enhanced user data saved successfully");
      log("👤 User ID: ${userInfo["sub"]}");
      log("📧 Email: ${userInfo["email"]}");
      log("🎭 Roles: $roles");
    } catch (e) {
      log("❌ Error saving user data: $e");
      throw Exception('Failed to save user data: $e');
    }
  }

  /// Extract user roles from token payload
  List<String> _extractUserRoles(Map<String, dynamic> userInfo) {
    final roles = <String>[];

    // Check realm_access roles
    if (userInfo["realm_access"] != null &&
        userInfo["realm_access"]["roles"] != null) {
      final realmRoles = userInfo["realm_access"]["roles"] as List?;
      if (realmRoles != null) {
        roles.addAll(realmRoles.cast<String>());
      }
    }

    // Check resource_access roles
    if (userInfo["resource_access"] != null) {
      final resourceAccess =
          userInfo["resource_access"] as Map<String, dynamic>?;
      resourceAccess?.forEach((key, value) {
        if (value is Map<String, dynamic> && value["roles"] != null) {
          final resourceRoles = value["roles"] as List?;
          if (resourceRoles != null) {
            roles.addAll(resourceRoles.cast<String>());
          }
        }
      });
    }

    return roles.toSet().toList(); // Remove duplicates
  }

  /// Log comprehensive troubleshooting guide
  void _logTroubleshootingGuide(dynamic error) {
    log('🔍 ===== TROUBLESHOOTING GUIDE =====');

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('unauthorized_client')) {
      log('🔍 ISSUE: Unauthorized Client');
      log('🔧 SOLUTIONS:');
      log('   1. Verify client ID "onegate-sso" exists in Keycloak realm "fstech"');
      log('   2. Check if client is enabled in Keycloak');
      log('   3. Verify redirect URI "com.cubeonebiz.gate://login-callback" is registered');
      log('   4. Check client access type (public vs confidential)');
    } else if (errorString.contains('invalid_client')) {
      log('🔍 ISSUE: Invalid Client');
      log('🔧 SOLUTIONS:');
      log('   1. Check client secret if using confidential client');
      log('   2. Verify client configuration in Keycloak');
      log('   3. Try switching between public and confidential client modes');
    } else if (errorString.contains('pkce')) {
      log('🔍 ISSUE: PKCE Configuration');
      log('🔧 SOLUTIONS:');
      log('   1. Enable PKCE in Keycloak client settings');
      log('   2. Set "Proof Key for Code Exchange Code Challenge Method" to S256');
      log('   3. Ensure client supports PKCE');
    } else if (errorString.contains('redirect_uri')) {
      log('🔍 ISSUE: Redirect URI Mismatch');
      log('🔧 SOLUTIONS:');
      log('   1. Add "com.cubeonebiz.gate://login-callback" to Valid Redirect URIs');
      log('   2. Check Android manifest intent filter configuration');
      log('   3. Verify bundle identifier matches');
    } else {
      log('🔍 ISSUE: General Authentication Error');
      log('🔧 GENERAL SOLUTIONS:');
      log('   1. Check network connectivity');
      log('   2. Verify Keycloak server is accessible');
      log('   3. Check SSL certificate issues');
      log('   4. Review Keycloak client configuration');
    }

    log('📋 KEYCLOAK CLIENT CHECKLIST:');
    log('   □ Client ID: onegate-sso');
    log('   □ Client enabled: true');
    log('   □ Access Type: public or confidential');
    log('   □ Standard Flow Enabled: true');
    log('   □ Direct Access Grants Enabled: true');
    log('   □ Valid Redirect URIs: com.cubeonebiz.gate://login-callback');
    log('   □ PKCE Code Challenge Method: S256 (if supported)');
    log('🔍 ================================');
  }
}
