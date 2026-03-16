import 'dart:developer';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/data/datasources/keycloack_config.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/services/auth_service/token_notification_service.dart';

/// Enhanced logout service that properly terminates Keycloak sessions
/// and clears all authentication state comprehensively
class EnhancedLogoutService {
  static final EnhancedLogoutService _instance =
      EnhancedLogoutService._internal();
  factory EnhancedLogoutService() => _instance;
  EnhancedLogoutService._internal();

  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final TokenNotificationService _notificationService =
      TokenNotificationService();

  // Storage keys for secure storage
  static const String _accessTokenKey = 'access_token_secure';
  static const String _refreshTokenKey = 'refresh_token_secure';
  static const String _idTokenKey = 'id_token_secure';

  /// Perform complete logout with Keycloak end session call
  Future<LogoutResult> performCompleteLogout({
    bool showNotifications = true,
    bool clearAllPreferences = true,
  }) async {
    final result = LogoutResult();

    try {
      log("🚪 Starting enhanced logout process...");

      if (showNotifications) {
        _notificationService.showTokenRefreshProgress(
            message: "🚪 Logging out, please wait...");
      }

      // Step 1: Get current tokens for end session call
      final idToken = await _secureStorage.read(key: _idTokenKey);

      // Step 2: Call Keycloak end session endpoint
      if (idToken != null) {
        result.keycloakEndSessionResult =
            await _performKeycloakEndSession(idToken);
      } else {
        log("⚠️ No ID token available for Keycloak end session");
        result.keycloakEndSessionResult = false;
      }

      // Step 3: Clear all tokens from secure storage
      result.secureStorageCleared = await _clearSecureStorage();

      // Step 4: Clear tokens from SharedPreferences (GateStorage)
      result.sharedPreferencesCleared =
          await _clearSharedPreferences(clearAllPreferences);

      // Step 5: Clear additional authentication data
      result.additionalDataCleared = await _clearAdditionalAuthData();

      // Step 6: Verify complete cleanup
      result.verificationPassed = await _verifyCompleteCleanup();

      // Determine overall success
      result.success = result.secureStorageCleared &&
          result.sharedPreferencesCleared &&
          result.additionalDataCleared;

      if (showNotifications) {
        if (result.success) {
          _notificationService.showTokenRefreshSuccess(newToken: null);
        } else {
          _notificationService.showTokenRefreshFailure(
              errorMessage: "⚠️ Logout completed with some issues");
        }
      }

      log("✅ Enhanced logout completed. Success: ${result.success}");
      _logLogoutResult(result);

      return result;
    } catch (e) {
      log("❌ Error during enhanced logout: $e");
      result.success = false;
      result.error = e.toString();

      if (showNotifications) {
        _notificationService.showTokenRefreshFailure(
            errorMessage: "Logout error: ${e.toString()}");
      }

      return result;
    }
  }

  /// Call Keycloak end session endpoint using flutter_appauth
  Future<bool> _performKeycloakEndSession(String idToken) async {
    try {
      log("🔚 Calling Keycloak end session endpoint...");

      // Create end session request
      final endSessionRequest = EndSessionRequest(
        idTokenHint: idToken,
        postLogoutRedirectUrl: AppAuthConfigManager.postLogoutRedirectUrl,
        serviceConfiguration: AppAuthConfigManager.getServiceConfiguration(),
      );

      // Perform end session
      await _appAuth.endSession(endSessionRequest);

      log("✅ Keycloak end session completed successfully");
      return true;
    } catch (e) {
      log("❌ Error calling Keycloak end session: $e");
      // Don't fail the entire logout process if end session fails
      return false;
    }
  }

  /// Clear all tokens from Flutter secure storage
  Future<bool> _clearSecureStorage() async {
    try {
      log("🧹 Clearing secure storage...");

      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _idTokenKey);

      // Clear any other secure storage keys that might exist
      await _secureStorage.deleteAll();

      log("✅ Secure storage cleared");
      return true;
    } catch (e) {
      log("❌ Error clearing secure storage: $e");
      return false;
    }
  }

  /// Clear authentication data from SharedPreferences
  Future<bool> _clearSharedPreferences(bool clearAll) async {
    try {
      log("🧹 Clearing SharedPreferences...");

      final prefs = await SharedPreferences.getInstance();

      if (clearAll) {
        // Clear all preferences
        await prefs.clear();
        log("✅ All SharedPreferences cleared");
      } else {
        // Clear only authentication-related preferences
        final authKeys = [
          'access_token',
          'access_token_response', // PreferenceUtils full response
          'refresh_token',
          'id_token',
          'token_expiry',
          'user_id',
          'username',
          'role',
          'society_id',
          'user_email',
          'user_full_name',
          'user_roles',
          'session_timestamp',
          'selected_gate',
          'selected_gate_id',
          'selected_gate_type',
          'hasNavigatedToGateSettings',
        ];

        for (final key in authKeys) {
          await prefs.remove(key);
        }

        log("✅ Authentication-related SharedPreferences cleared");
      }

      return true;
    } catch (e) {
      log("❌ Error clearing SharedPreferences: $e");
      return false;
    }
  }

  /// Clear additional authentication data using GateStorage
  Future<bool> _clearAdditionalAuthData() async {
    try {
      log("🧹 Clearing additional authentication data...");

      final gateStorage = GateStorage();

      // Clear all authentication tokens
      await gateStorage.clearTokens();

      // Clear user data
      await gateStorage.clearStorage('user_id');
      await gateStorage.clearStorage('username');
      await gateStorage.clearStorage('role');
      await gateStorage.clearStorage('society_id');
      await gateStorage.clearStorage('user_email');
      await gateStorage.clearStorage('user_full_name');
      await gateStorage.clearStorage('user_roles');
      await gateStorage.clearStorage('session_timestamp');

      // Clear gate selection data
      await gateStorage.clearStorage('selected_gate');
      await gateStorage.clearStorage('selected_gate_id');
      await gateStorage.clearStorage('selected_gate_type');

      log("✅ Additional authentication data cleared");
      return true;
    } catch (e) {
      log("❌ Error clearing additional authentication data: $e");
      return false;
    }
  }

  /// Verify that all authentication data has been cleared
  Future<bool> _verifyCompleteCleanup() async {
    try {
      log("🔍 Verifying complete cleanup...");

      // Check secure storage
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      final idToken = await _secureStorage.read(key: _idTokenKey);

      if (accessToken != null || refreshToken != null || idToken != null) {
        log("⚠️ Some tokens still present in secure storage");
        return false;
      }

      // Check SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final storedAccessToken = prefs.getString('access_token');
      final storedUserId = prefs.getString('user_id');

      if (storedAccessToken != null || storedUserId != null) {
        log("⚠️ Some authentication data still present in SharedPreferences");
        return false;
      }

      log("✅ Cleanup verification passed");
      return true;
    } catch (e) {
      log("❌ Error during cleanup verification: $e");
      return false;
    }
  }

  /// Log detailed logout result for debugging
  void _logLogoutResult(LogoutResult result) {
    log("📊 LOGOUT RESULT SUMMARY:");
    log("   • Overall Success: ${result.success}");
    log("   • Keycloak End Session: ${result.keycloakEndSessionResult}");
    log("   • Secure Storage Cleared: ${result.secureStorageCleared}");
    log("   • SharedPreferences Cleared: ${result.sharedPreferencesCleared}");
    log("   • Additional Data Cleared: ${result.additionalDataCleared}");
    log("   • Verification Passed: ${result.verificationPassed}");
    if (result.error != null) {
      log("   • Error: ${result.error}");
    }
  }

  /// Quick logout method for emergency situations
  Future<bool> performQuickLogout() async {
    try {
      log("⚡ Performing quick logout...");

      // Clear secure storage
      await _secureStorage.deleteAll();

      // Clear all SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      log("✅ Quick logout completed");
      return true;
    } catch (e) {
      log("❌ Error during quick logout: $e");
      return false;
    }
  }
}

/// Result object for logout operations
class LogoutResult {
  bool success = false;
  bool keycloakEndSessionResult = false;
  bool secureStorageCleared = false;
  bool sharedPreferencesCleared = false;
  bool additionalDataCleared = false;
  bool verificationPassed = false;
  String? error;

  /// Get a summary of any issues encountered
  List<String> getIssues() {
    final issues = <String>[];

    if (!keycloakEndSessionResult) {
      issues.add("Keycloak end session failed or skipped");
    }
    if (!secureStorageCleared) {
      issues.add("Secure storage clearing failed");
    }
    if (!sharedPreferencesCleared) {
      issues.add("SharedPreferences clearing failed");
    }
    if (!additionalDataCleared) {
      issues.add("Additional data clearing failed");
    }
    if (!verificationPassed) {
      issues.add("Cleanup verification failed");
    }
    if (error != null) {
      issues.add("Error occurred: $error");
    }

    return issues;
  }

  /// Check if logout was completely successful
  bool get isCompleteSuccess =>
      success && keycloakEndSessionResult && verificationPassed;
}
