import 'dart:convert';
import 'dart:developer';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_tokens.dart';

/// Secure storage wrapper for authentication tokens
class AuthStorage {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Storage keys
  static const String _tokensKey = 'auth_tokens_v2';
  static const String _userInfoKey = 'user_info_v2';

  /// Store authentication tokens securely
  Future<void> storeTokens(AuthTokens tokens) async {
    try {
      final tokensJson = jsonEncode(tokens.toJson());
      await _secureStorage.write(key: _tokensKey, value: tokensJson);
      log('✅ Tokens stored securely');
    } catch (e) {
      log('❌ Error storing tokens: $e');
      rethrow;
    }
  }

  /// Retrieve authentication tokens from secure storage
  Future<AuthTokens?> getTokens() async {
    try {
      final tokensJson = await _secureStorage.read(key: _tokensKey);
      if (tokensJson == null) {
        log('ℹ️ No tokens found in secure storage');
        return null;
      }

      final tokensMap = jsonDecode(tokensJson) as Map<String, dynamic>;
      final tokens = AuthTokens.fromJson(tokensMap);
      
      // Check expiration status
      final updatedTokens = tokens.withExpirationCheck();
      
      log('✅ Tokens retrieved from secure storage');
      return updatedTokens;
    } catch (e) {
      log('❌ Error retrieving tokens: $e');
      return null;
    }
  }

  /// Store user information
  Future<void> storeUserInfo(Map<String, dynamic> userInfo) async {
    try {
      final userInfoJson = jsonEncode(userInfo);
      await _secureStorage.write(key: _userInfoKey, value: userInfoJson);
      log('✅ User info stored securely');
    } catch (e) {
      log('❌ Error storing user info: $e');
      rethrow;
    }
  }

  /// Retrieve user information
  Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final userInfoJson = await _secureStorage.read(key: _userInfoKey);
      if (userInfoJson == null) {
        log('ℹ️ No user info found in secure storage');
        return null;
      }

      final userInfo = jsonDecode(userInfoJson) as Map<String, dynamic>;
      log('✅ User info retrieved from secure storage');
      return userInfo;
    } catch (e) {
      log('❌ Error retrieving user info: $e');
      return null;
    }
  }

  /// Clear all stored authentication data
  Future<void> clearAll() async {
    try {
      await _secureStorage.delete(key: _tokensKey);
      await _secureStorage.delete(key: _userInfoKey);
      log('✅ All authentication data cleared from secure storage');
    } catch (e) {
      log('❌ Error clearing authentication data: $e');
      rethrow;
    }
  }

  /// Check if tokens exist in storage
  Future<bool> hasTokens() async {
    try {
      final tokensJson = await _secureStorage.read(key: _tokensKey);
      return tokensJson != null;
    } catch (e) {
      log('❌ Error checking for tokens: $e');
      return false;
    }
  }

  /// Get only the access token (for quick access)
  Future<String?> getAccessToken() async {
    try {
      final tokens = await getTokens();
      return tokens?.accessToken;
    } catch (e) {
      log('❌ Error getting access token: $e');
      return null;
    }
  }

  /// Get only the refresh token (for quick access)
  Future<String?> getRefreshToken() async {
    try {
      final tokens = await getTokens();
      return tokens?.refreshToken;
    } catch (e) {
      log('❌ Error getting refresh token: $e');
      return null;
    }
  }

  /// Check if stored tokens are expired
  Future<bool> areTokensExpired() async {
    try {
      final tokens = await getTokens();
      if (tokens == null) return true;
      
      return tokens.isExpired;
    } catch (e) {
      log('❌ Error checking token expiration: $e');
      return true;
    }
  }

  /// Get time until token expiration
  Future<Duration?> getTimeUntilExpiration() async {
    try {
      final tokens = await getTokens();
      return tokens?.timeUntilExpiration;
    } catch (e) {
      log('❌ Error getting time until expiration: $e');
      return null;
    }
  }
}
