import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/datasources/keycloack_config.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_logout_service.dart';

class AuthService {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final GateStorage gateStorage;
  final RemoteDataSource remoteDataSource;

  // Enhanced token refresh manager
  late final EnhancedTokenRefreshManager _tokenRefreshManager;

  // Authentication state stream controller
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();

  // Storage keys for secure storage
  static const String _accessTokenKey = 'access_token_secure';
  static const String _refreshTokenKey = 'refresh_token_secure';
  static const String _idTokenKey = 'id_token_secure';

  AuthService({
    required this.gateStorage,
    required this.remoteDataSource,
  }) {
    _tokenRefreshManager = EnhancedTokenRefreshManager();
  }

  /// Get access to the enhanced token refresh manager
  EnhancedTokenRefreshManager get tokenRefreshManager => _tokenRefreshManager;

  Future<void> initialize() async {
    try {
      // Initialize the enhanced token refresh manager
      await _tokenRefreshManager.initialize(gateStorage);
      log("✅ AppAuth service and enhanced token refresh manager initialized successfully");
    } catch (e) {
      log('❌ Error initializing AppAuth service: $e');
      throw Exception('Failed to initialize AppAuth service: $e');
    }
  }

  Future<Map<String, dynamic>?> login() async {
    try {
      log('🔐 ===== STARTING APPAUTH LOGIN FLOW =====');

      // Display comprehensive client configuration
      AppAuthConfigManager.logClientConfiguration(includeSecret: true);

      log('🚀 Initiating Authorization and Token Exchange...');
      log('📱 Using authorizeAndExchangeCode for automatic PKCE handling');

      // Use authorizeAndExchangeCode for automatic PKCE handling
      final AuthorizationTokenResponse result =
          await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AppAuthConfigManager.clientId,
          AppAuthConfigManager.redirectUrl,
          serviceConfiguration: AppAuthConfigManager.getServiceConfiguration(),
          scopes: AppAuthConfigManager.scopes,
          // Include client secret for confidential clients
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

      log("✅ ===== AUTHORIZATION SUCCESSFUL =====");
      log("🔑 Access Token: ${result.accessToken!.substring(0, 20)}... (${result.accessToken!.length} chars)");
      log("🔄 Refresh Token: ${result.refreshToken != null ? 'Present (${result.refreshToken!.substring(0, 20)}...)' : 'Not provided'}");
      log("🆔 ID Token: ${result.idToken != null ? 'Present (${result.idToken!.substring(0, 20)}...)' : 'Not provided'}");
      log("⏰ Token Expiry: ${result.accessTokenExpirationDateTime ?? 'Not specified'}");

      // Print full tokens for debugging (be careful in production!)
      log("🔐 ===== FULL TOKEN DETAILS (DEBUG) =====");
      log("🔑 FULL ACCESS TOKEN:");
      log(result.accessToken!);
      log("🔄 FULL REFRESH TOKEN:");
      log(result.refreshToken ?? 'Not provided');
      log("🆔 FULL ID TOKEN:");
      log(result.idToken ?? 'Not provided');

      // Decode and print token contents
      _printTokenContents("ACCESS TOKEN", result.accessToken!);
      if (result.idToken != null) {
        _printTokenContents("ID TOKEN", result.idToken!);
      }
      log("🔐 ===================================");

      // Step 3: Store tokens securely
      log("💾 Storing tokens securely...");
      await _storeTokensFromAuthResponse(result);

      // Step 4: Get user info from Keycloak
      log("👤 Fetching user info from Keycloak...");
      final userInfo = await _getUserInfo(result.accessToken!);

      // Step 5: Save user data to local storage
      log("💾 Saving user data to local storage...");
      await _saveUserData(userInfo);

      log("✅ ===== LOGIN COMPLETED SUCCESSFULLY =====");

      // Notify authentication state change
      _notifyAuthStateChange(true);

      return userInfo;
    } catch (e) {
      log('❌ ===== LOGIN FAILED =====');
      log('❌ Error Type: ${e.runtimeType}');
      log('❌ Error Message: $e');

      if (e.toString().contains('unauthorized_client')) {
        log('🔍 DIAGNOSIS: Client credentials are invalid');
        log('🔍 POSSIBLE CAUSES:');
        log('   • Client ID "onegate-sso" does not exist in realm "fstech"');
        log('   • Redirect URI "com.cubeonebiz.gate://login-callback" is not registered');
        log('   • Client is configured as confidential but no secret provided');
        log('   • Client is disabled in Keycloak');
        log('🔧 SOLUTION: Check Keycloak Admin Console → fstech realm → Clients → onegate-sso');
      } else if (e.toString().contains('PKCE')) {
        log('🔍 DIAGNOSIS: PKCE configuration issue');
        log('🔧 SOLUTION: Ensure PKCE is enabled in Keycloak client settings');
      }

      log('❌ ========================');
      throw Exception('Login failed: $e');
    }
  }

  /// ✅ **Implement fetchSocieties**
  Future<List<dynamic>> fetchSocieties(String userId) async {
    try {
      return await remoteDataSource.fetchSocieties(userId);
    } catch (e) {
      log('❌ Error fetching societies: $e');
      throw Exception('Failed to fetch societies: $e');
    }
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

  /// Store tokens securely with JWT-based duration calculation
  Future<void> _storeTokens(TokenResponse tokenResponse) async {
    try {
      log('💾 Storing tokens with JWT-based duration calculation...');

      // Store access token and analyze its JWT claims
      if (tokenResponse.accessToken != null) {
        await _secureStorage.write(
            key: _accessTokenKey, value: tokenResponse.accessToken!);
        await gateStorage.saveAccessToken(tokenResponse.accessToken!);

        // Log detailed token analysis
        JwtTokenUtility.logTokenDetails("ACCESS", tokenResponse.accessToken!);
      }

      // Store refresh token and check if it's a JWT
      if (tokenResponse.refreshToken != null) {
        await _secureStorage.write(
            key: _refreshTokenKey, value: tokenResponse.refreshToken!);
        await gateStorage.saveRefreshToken(tokenResponse.refreshToken!);

        // Analyze refresh token if it's a JWT
        if (JwtTokenUtility.isValidJwtToken(tokenResponse.refreshToken!)) {
          JwtTokenUtility.logTokenDetails(
              "REFRESH", tokenResponse.refreshToken!);
          log("🔄 Refresh token is JWT with expiration info");
        } else {
          log("🔄 Refresh token is opaque (server-managed expiration)");
        }
      }

      if (tokenResponse.idToken != null) {
        await _secureStorage.write(
            key: _idTokenKey, value: tokenResponse.idToken!);
      }

      // Store token expiry time using JWT claims (iat/exp) for accuracy
      if (tokenResponse.accessToken != null) {
        final expiryTime =
            JwtTokenUtility.getTokenExpirationTime(tokenResponse.accessToken!);
        final issuedTime =
            JwtTokenUtility.getTokenIssuedAtTime(tokenResponse.accessToken!);

        if (expiryTime != null && issuedTime != null) {
          await gateStorage.saveTokenExpiry(expiryTime);

          // Calculate actual duration from JWT claims
          final actualDuration = expiryTime.difference(issuedTime);
          log('⏱️ JWT Token Duration Analysis:');
          log('   • Issued At (iat): ${issuedTime.toIso8601String()}');
          log('   • Expires At (exp): ${expiryTime.toIso8601String()}');
          log('   • Calculated Duration: ${actualDuration.inMinutes}min ${actualDuration.inSeconds % 60}s');

          // Verify against server-provided expiry if available
          if (tokenResponse.accessTokenExpirationDateTime != null) {
            final serverExpiry = tokenResponse.accessTokenExpirationDateTime!;
            final timeDiff = expiryTime.difference(serverExpiry).abs();
            if (timeDiff.inSeconds > 5) {
              log('⚠️ JWT vs Server expiry mismatch: ${timeDiff.inSeconds}s difference');
            } else {
              log('✅ JWT and server expiry times match');
            }
          }
        } else if (tokenResponse.accessTokenExpirationDateTime != null) {
          // Fallback to server-provided expiry
          await gateStorage
              .saveTokenExpiry(tokenResponse.accessTokenExpirationDateTime!);
          log('⚠️ Using server-provided expiry (JWT parsing failed)');
        } else {
          log('❌ No expiry information available - this may cause issues');
        }
      }

      log('✅ Tokens stored successfully with JWT-based duration');
    } catch (e) {
      log('❌ Error storing tokens: $e');
      throw Exception('Failed to store tokens: $e');
    }
  }

  /// Get user info from Keycloak userinfo endpoint
  Future<Map<String, dynamic>> _getUserInfo(String accessToken) async {
    try {
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

  /// Refresh access token using refresh token
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);

      if (refreshToken == null) {
        log('❌ No refresh token available');
        return false;
      }

      final TokenResponse tokenResponse = await _appAuth.token(
        AppAuthConfigManager.getRefreshTokenRequest(refreshToken),
      );

      if (tokenResponse.accessToken == null) {
        log('❌ Token refresh failed');
        return false;
      }

      await _storeTokens(tokenResponse);
      log('✅ Token refreshed successfully');
      return true;
    } catch (e) {
      log('❌ Error refreshing token: $e');
      return false;
    }
  }

  /// Get current access token (refresh if needed) - Enhanced version
  Future<String?> getValidAccessToken() async {
    try {
      // Use the enhanced token refresh manager for better token handling
      return await _tokenRefreshManager.getValidAccessToken();
    } catch (e) {
      log('❌ Error getting valid access token: $e');
      return null;
    }
  }

  /// Logout user and clear all tokens - Enhanced version with Keycloak end session
  Future<LogoutResult> logout({bool clearAllPreferences = true}) async {
    try {
      log('🚪 Starting enhanced logout with Keycloak end session...');

      // Use enhanced logout service for complete logout
      final logoutService = EnhancedLogoutService();
      final result = await logoutService.performCompleteLogout(
        showNotifications: true,
        clearAllPreferences: clearAllPreferences,
      );

      // Stop token refresh manager
      _tokenRefreshManager.stopPeriodicRefreshCheck();

      if (result.success) {
        log('✅ Enhanced logout completed successfully');
        // Notify authentication state change
        _notifyAuthStateChange(false);
      } else {
        log('⚠️ Enhanced logout completed with issues: ${result.getIssues()}');
      }

      return result;
    } catch (e) {
      log('❌ Error during enhanced logout: $e');

      // Return failed result
      final result = LogoutResult();
      result.success = false;
      result.error = e.toString();
      return result;
    }
  }

  /// Quick logout method for emergency situations
  Future<bool> quickLogout() async {
    try {
      log('⚡ Performing quick logout...');

      final logoutService = EnhancedLogoutService();
      final success = await logoutService.performQuickLogout();

      // Stop token refresh manager
      _tokenRefreshManager.stopPeriodicRefreshCheck();

      if (success) {
        // Notify authentication state change
        _notifyAuthStateChange(false);
      }

      return success;
    } catch (e) {
      log('❌ Error during quick logout: $e');
      return false;
    }
  }

  /// Decode and print JWT token contents - Enhanced version
  void _printTokenContents(String tokenType, String token) {
    // Use the enhanced JWT utility for better token parsing
    JwtTokenUtility.logTokenDetails(tokenType, token);
  }

  /// Enhanced user session management
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

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    try {
      final accessToken = await gateStorage.getAccessToken();
      if (accessToken == null) return false;

      final isExpired = await gateStorage.isTokenExpired();
      if (isExpired) {
        // Try to refresh token
        final refreshed = await refreshToken();
        return refreshed;
      }

      return true;
    } catch (e) {
      log("❌ Error checking authentication: $e");
      return false;
    }
  }

  /// Get current user session information
  Future<Map<String, dynamic>?> getCurrentUserSession() async {
    try {
      final userId = await gateStorage.getUserId();
      final username = await gateStorage.getUsername();
      final email = await gateStorage.getUserEmail();
      final fullName = await gateStorage.getUserFullName();
      final roles = await gateStorage.getUserRoles();
      final sessionTimestamp = await gateStorage.getSessionTimestamp();

      if (userId == null) return null;

      return {
        'userId': userId,
        'username': username,
        'email': email,
        'fullName': fullName,
        'roles': roles,
        'sessionTimestamp': sessionTimestamp?.toIso8601String(),
        'isAuthenticated': await isAuthenticated(),
      };
    } catch (e) {
      log("❌ Error getting user session: $e");
      return null;
    }
  }

  /// Check if user is logged in (alias for isAuthenticated for compatibility)
  Future<bool> isLoggedIn() async {
    try {
      return await isAuthenticated();
    } catch (e) {
      log("❌ Error checking login status: $e");
      return false;
    }
  }

  /// Stream of authentication state changes
  Stream<bool> get isLoggedInStream => _authStateController.stream;

  /// Notify authentication state change
  void _notifyAuthStateChange(bool isLoggedIn) {
    if (!_authStateController.isClosed) {
      _authStateController.add(isLoggedIn);
    }
  }

  /// Dispose resources
  void dispose() {
    _authStateController.close();
    _tokenRefreshManager.dispose();
  }
}
