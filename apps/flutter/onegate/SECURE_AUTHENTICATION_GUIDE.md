# Secure Authentication System for OneGate

## 🎯 Overview

This document describes the new unified secure authentication system for the OneGate Flutter app. This system fixes session expiry issues and provides robust token management using `flutter_appauth` and `flutter_secure_storage`.

## ✅ Key Features

- **JWT-based token expiry detection** - Automatically decodes JWT tokens to determine exact expiry times
- **Automatic token refresh** - Schedules refresh 2 minutes before token expiry
- **Secure token storage** - Uses `flutter_secure_storage` with encryption
- **Concurrent refresh protection** - Prevents multiple simultaneous refresh attempts
- **Automatic HTTP token injection** - Dio interceptor adds Bearer tokens to all requests
- **401 error handling** - Automatically refreshes tokens and retries failed requests
- **Clean architecture** - Follows hexagonal patterns with clear separation of concerns

## 🏗️ Architecture

### Core Components

1. **SecureTokenManager** - Handles all token operations (store, retrieve, refresh)
2. **UnifiedAuthService** - Main authentication service with clean API
3. **SecureAuthInterceptor** - Dio interceptor for automatic token management
4. **SecureDioFactory** - Creates pre-configured Dio instances

### Dependencies

- `flutter_appauth: ^7.0.0` - OAuth/OIDC authentication
- `flutter_secure_storage: ^9.2.2` - Secure token storage
- `dio: ^5.8.0` - HTTP client with interceptors

## 🚀 Quick Start

### 1. Initialize the Authentication System

```dart
import 'package:flutter_onegate/services/auth_service/unified_auth_service.dart';
import 'package:flutter_onegate/services/auth_service/secure_auth_interceptor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize authentication
  final authService = UnifiedAuthService();
  await authService.initialize();
  
  runApp(MyApp());
}
```

### 2. Perform Login

```dart
final authService = UnifiedAuthService();

try {
  final userInfo = await authService.login();
  if (userInfo != null) {
    print('Login successful: ${userInfo['name']}');
    // Navigate to authenticated screens
  }
} catch (e) {
  print('Login failed: $e');
  // Handle login error
}
```

### 3. Make Authenticated API Calls

```dart
// Create authenticated Dio instance
final dio = SecureDioFactory.createAuthenticatedDio(
  baseUrl: 'https://your-api.com',
);

// Make API calls - tokens are automatically managed
final response = await dio.get('/api/user/profile');
// The interceptor will:
// 1. Add Bearer token automatically
// 2. Refresh token if expired
// 3. Retry request if 401 received
```

### 4. Listen to Authentication State

```dart
final authService = UnifiedAuthService();

authService.authStateStream.listen((isAuthenticated) {
  if (isAuthenticated) {
    // User is logged in
    Navigator.pushReplacementNamed(context, '/home');
  } else {
    // User is logged out
    Navigator.pushReplacementNamed(context, '/login');
  }
});
```

## 🔧 Configuration

### Token Refresh Timing

The system automatically calculates optimal refresh timing based on JWT `exp` claims:
- Tokens are refreshed **2 minutes before expiry**
- If tokens expire within 2 minutes, immediate refresh is triggered
- Failed refresh attempts result in automatic logout

### Secure Storage Configuration

Tokens are stored using `flutter_secure_storage` with platform-specific encryption:

**Android:**
- Uses encrypted SharedPreferences
- Keys are stored in Android Keystore

**iOS:**
- Uses Keychain with `first_unlock_this_device` accessibility
- Provides secure storage even when device is locked

### HTTP Request Configuration

The `SecureAuthInterceptor` automatically:
- Adds `Authorization: Bearer <token>` headers
- Skips authentication for specific endpoints (login, register, public)
- Handles 401 responses with token refresh and retry
- Prevents infinite retry loops

## 📱 Usage Examples

### Check Authentication Status

```dart
final authService = UnifiedAuthService();
final isAuthenticated = await authService.isAuthenticated();

if (isAuthenticated) {
  // User is logged in
  final userInfo = await authService.getCurrentUser();
  print('Welcome ${userInfo?['name']}');
}
```

### Manual Token Refresh

```dart
final authService = UnifiedAuthService();
final success = await authService.refreshTokens();

if (success) {
  print('Tokens refreshed successfully');
} else {
  print('Token refresh failed - user needs to login again');
}
```

### Role-Based Access Control

```dart
final authService = UnifiedAuthService();
final hasAdminRole = await authService.hasRole('admin');

if (hasAdminRole) {
  // Show admin features
}
```

### Logout

```dart
final authService = UnifiedAuthService();
await authService.logout();
// All tokens are cleared from secure storage
// Auth state stream will emit false
```

## 🧪 Testing

### Running Tests

```bash
# Run all authentication tests
flutter test test/services/auth_service/

# Run specific test files
flutter test test/services/auth_service/secure_token_manager_test.dart
flutter test test/services/auth_service/unified_auth_service_test.dart
```

### Test Coverage

The test suite covers:
- Token storage and retrieval
- Token refresh logic
- Concurrent refresh protection
- Authentication status checks
- Error handling scenarios
- Mock integration testing

## 🔍 Debugging

### Enable Debug Logging

The system provides comprehensive logging for debugging:

```dart
import 'dart:developer';

// All authentication operations are logged with emojis for easy identification:
// 🔐 - Authentication operations
// 🔄 - Token refresh operations
// 💾 - Storage operations
// ⏰ - Scheduling operations
// ❌ - Errors
// ✅ - Success operations
```

### Common Issues and Solutions

**Issue: Session expired modal still appears**
- **Cause**: Multiple authentication systems running simultaneously
- **Solution**: Ensure only the new `UnifiedAuthService` is used

**Issue: Tokens not refreshing automatically**
- **Cause**: JWT tokens missing `exp` claim or invalid format
- **Solution**: Check Keycloak configuration and token format

**Issue: 401 errors not handled**
- **Cause**: `SecureAuthInterceptor` not added to Dio instance
- **Solution**: Use `SecureDioFactory.createAuthenticatedDio()`

## 🔄 Migration from Existing System

### Step 1: Replace Authentication Service

```dart
// Old
final authService = GetIt.I<AuthService>();

// New
final authService = UnifiedAuthService();
await authService.initialize();
```

### Step 2: Update API Clients

```dart
// Old
final dio = Dio();
dio.interceptors.add(OldAuthInterceptor());

// New
final dio = SecureDioFactory.createAuthenticatedDio();
```

### Step 3: Update Login/Logout Flows

```dart
// Old
await authService.login();
await authService.logout();

// New
final userInfo = await authService.login();
await authService.logout();
```

## 🛡️ Security Considerations

- **Token Storage**: All tokens are encrypted using platform-specific secure storage
- **Network Security**: HTTPS is enforced for all authentication endpoints
- **Token Refresh**: Refresh tokens are used only once and replaced on each refresh
- **Concurrent Protection**: Multiple refresh attempts are serialized to prevent race conditions
- **Error Handling**: Sensitive information is not logged in production builds

## 📚 API Reference

See the individual class documentation for detailed API reference:
- `SecureTokenManager` - Token management operations
- `UnifiedAuthService` - Main authentication interface
- `SecureAuthInterceptor` - HTTP request interceptor
- `SecureDioFactory` - Dio instance factory
