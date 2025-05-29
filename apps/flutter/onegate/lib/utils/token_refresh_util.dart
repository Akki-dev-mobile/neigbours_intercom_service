import 'dart:convert';
import 'dart:developer';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/keycloack_config.dart';
import 'package:http/http.dart' as http;

class TokenRefreshUtil {
  static final GateStorage _gateStorage = GateStorage();

  // Flag to prevent multiple simultaneous refresh attempts
  static bool _isRefreshing = false;

  /// Refreshes the access token using the refresh token if needed
  /// Returns true if token was refreshed successfully or wasn't needed
  /// Returns false if refresh failed
  static Future<bool> refreshTokenIfNeeded() async {
    try {
      // Check if token is expired
      final isExpired = await _gateStorage.isTokenExpired();

      if (!isExpired) {
        // Token is still valid, no need to refresh
        return true;
      }

      // Prevent multiple simultaneous refresh attempts
      if (_isRefreshing) {
        // Wait for the ongoing refresh to complete
        int attempts = 0;
        while (_isRefreshing && attempts < 10) {
          await Future.delayed(const Duration(milliseconds: 200));
          attempts++;
        }

        // Check if token is still expired after waiting
        return !(await _gateStorage.isTokenExpired());
      }

      _isRefreshing = true;

      try {
        // Get the refresh token
        final refreshToken = await _gateStorage.getRefreshToken();

        if (refreshToken == null) {
          log('❌ No refresh token available');
          _isRefreshing = false;
          return false;
        }

        // Use AppAuth configuration for token refresh
        final tokenEndpoint = AppAuthConfigManager.tokenEndpoint;

        final response = await http.post(
          Uri.parse(tokenEndpoint),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'client_id': AppAuthConfigManager.clientId,
            'client_secret': AppAuthConfigManager.clientSecret,
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          },
        );

        if (response.statusCode == 200) {
          final tokenData = jsonDecode(response.body);
          final newAccessToken = tokenData['access_token'];
          final newRefreshToken = tokenData['refresh_token'];

          // Save the new tokens
          await _gateStorage.saveAccessToken(newAccessToken);
          await _gateStorage.saveRefreshToken(newRefreshToken);

          // Calculate and save token expiry time
          final expiresIn =
              tokenData['expires_in'] ?? 3600; // Default to 1 hour
          final expiryTime = DateTime.now().add(Duration(seconds: expiresIn));
          await _gateStorage.saveTokenExpiry(expiryTime);

          log('✅ Token refreshed successfully using manual refresh');
          _isRefreshing = false;
          return true;
        } else {
          log('❌ Failed to refresh token: ${response.statusCode} - ${response.body}');
          _isRefreshing = false;
          return false;
        }
      } finally {
        _isRefreshing = false;
      }
    } catch (e) {
      log('❌ Error in refreshTokenIfNeeded: $e');
      _isRefreshing = false;
      return false;
    }
  }

  /// Gets a valid access token, refreshing if necessary
  /// Returns null if unable to get a valid token
  static Future<String?> getValidAccessToken() async {
    final refreshed = await refreshTokenIfNeeded();

    if (refreshed) {
      return await _gateStorage.getAccessToken();
    }

    return null;
  }
}
