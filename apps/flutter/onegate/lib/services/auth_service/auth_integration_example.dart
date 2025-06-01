import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/services/auth_service/unified_auth_service.dart';
import 'package:flutter_onegate/services/auth_service/secure_auth_interceptor.dart';

/// Example integration showing how to use the new secure authentication system
/// This demonstrates the complete setup and usage patterns
class AuthIntegrationExample {
  static final UnifiedAuthService _authService = UnifiedAuthService();
  static late Dio _authenticatedDio;

  /// Initialize the authentication system
  /// Call this in your main() function or app initialization
  static Future<void> initializeAuth() async {
    try {
      log('🚀 Initializing secure authentication system...');
      
      // Initialize the unified auth service
      await _authService.initialize();
      
      // Create authenticated Dio instance
      _authenticatedDio = SecureDioFactory.createAuthenticatedDio(
        baseUrl: 'https://your-api-base-url.com',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      );
      
      log('✅ Secure authentication system initialized');
    } catch (e) {
      log('❌ Failed to initialize authentication: $e');
      rethrow;
    }
  }

  /// Example login flow
  static Future<bool> performLogin() async {
    try {
      log('🔐 Starting login process...');
      
      final userInfo = await _authService.login();
      if (userInfo != null) {
        log('✅ Login successful for user: ${userInfo['name']}');
        return true;
      }
      
      log('❌ Login failed - no user info received');
      return false;
    } catch (e) {
      log('❌ Login error: $e');
      return false;
    }
  }

  /// Example logout flow
  static Future<void> performLogout() async {
    try {
      log('🚪 Starting logout process...');
      await _authService.logout();
      log('✅ Logout successful');
    } catch (e) {
      log('❌ Logout error: $e');
    }
  }

  /// Example API call with automatic token management
  static Future<Map<String, dynamic>?> makeAuthenticatedApiCall(String endpoint) async {
    try {
      log('📡 Making authenticated API call to: $endpoint');
      
      // The SecureAuthInterceptor will automatically:
      // 1. Add the Bearer token to the request
      // 2. Refresh the token if it's expired/expiring
      // 3. Retry the request with the new token if 401 is received
      final response = await _authenticatedDio.get(endpoint);
      
      log('✅ API call successful: ${response.statusCode}');
      return response.data;
    } catch (e) {
      log('❌ API call failed: $e');
      return null;
    }
  }

  /// Example of checking authentication status
  static Future<bool> checkAuthStatus() async {
    try {
      final isAuthenticated = await _authService.isAuthenticated();
      log('🔍 Authentication status: ${isAuthenticated ? "Authenticated" : "Not authenticated"}');
      return isAuthenticated;
    } catch (e) {
      log('❌ Error checking auth status: $e');
      return false;
    }
  }

  /// Example of getting current user info
  static Future<Map<String, dynamic>?> getCurrentUserInfo() async {
    try {
      final userInfo = await _authService.getCurrentUser();
      if (userInfo != null) {
        log('👤 Current user: ${userInfo['name']} (${userInfo['email']})');
      } else {
        log('⚠️ No user info available');
      }
      return userInfo;
    } catch (e) {
      log('❌ Error getting user info: $e');
      return null;
    }
  }

  /// Example of manual token refresh
  static Future<bool> refreshTokensManually() async {
    try {
      log('🔄 Manually refreshing tokens...');
      final success = await _authService.refreshTokens();
      log(success ? '✅ Token refresh successful' : '❌ Token refresh failed');
      return success;
    } catch (e) {
      log('❌ Error refreshing tokens: $e');
      return false;
    }
  }

  /// Example of listening to auth state changes
  static void listenToAuthStateChanges() {
    _authService.authStateStream.listen((isAuthenticated) {
      log('🔔 Auth state changed: ${isAuthenticated ? "Logged in" : "Logged out"}');
      
      // Handle auth state changes in your app
      // For example, navigate to login screen if not authenticated
      if (!isAuthenticated) {
        // Navigate to login screen
        log('🔄 User not authenticated, should navigate to login');
      }
    });
  }

  /// Example widget that uses the authentication system
  static Widget buildAuthAwareWidget() {
    return StreamBuilder<bool>(
      stream: _authService.authStateStream,
      builder: (context, snapshot) {
        final isAuthenticated = snapshot.data ?? false;
        
        if (isAuthenticated) {
          return const AuthenticatedHomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }

  /// Example of role-based access control
  static Future<bool> checkUserPermission(String role) async {
    try {
      final hasRole = await _authService.hasRole(role);
      log('🔐 User has role "$role": $hasRole');
      return hasRole;
    } catch (e) {
      log('❌ Error checking user role: $e');
      return false;
    }
  }

  /// Cleanup resources
  static void dispose() {
    _authService.dispose();
    log('🗑️ Authentication system disposed');
  }
}

/// Example authenticated home screen
class AuthenticatedHomeScreen extends StatelessWidget {
  const AuthenticatedHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authenticated Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthIntegrationExample.performLogout(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome! You are authenticated.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => AuthIntegrationExample.makeAuthenticatedApiCall('/api/user/profile'),
              child: const Text('Make API Call'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => AuthIntegrationExample.getCurrentUserInfo(),
              child: const Text('Get User Info'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => AuthIntegrationExample.refreshTokensManually(),
              child: const Text('Refresh Tokens'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Example login screen
class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Please log in to continue'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => AuthIntegrationExample.performLogin(),
              child: const Text('Login with Keycloak'),
            ),
          ],
        ),
      ),
    );
  }
}
