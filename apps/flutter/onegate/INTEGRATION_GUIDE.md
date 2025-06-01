# OneGate Secure Authentication Integration Guide

## 🎯 Overview

This guide shows how to integrate the new secure authentication system into your OneGate Flutter app to fix session expiry issues and implement robust token management.

## ✅ What's Fixed

- **Session expiry modals** - No more unexpected "Session Expired" popups
- **Automatic token refresh** - Tokens refresh 2 minutes before expiry based on JWT `exp` claim
- **Secure token storage** - Uses `flutter_secure_storage` with encryption
- **Concurrent refresh protection** - Prevents multiple simultaneous refresh attempts
- **401 error handling** - Automatically refreshes tokens and retries failed requests

## 🚀 Quick Integration

### Step 1: Initialize Authentication in main.dart

```dart
import 'package:flutter_onegate/services/auth_service/unified_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the secure authentication system
  final authService = UnifiedAuthService();
  await authService.initialize();
  
  runApp(MyApp());
}
```

### Step 2: Replace Existing Authentication Calls

**Old Login:**
```dart
// Replace this
final authService = GetIt.I<AuthService>();
await authService.login();
```

**New Login:**
```dart
// With this
final authService = UnifiedAuthService();
try {
  final userInfo = await authService.login();
  if (userInfo != null) {
    print('Login successful: ${userInfo['name']}');
    // Navigate to authenticated screens
  }
} catch (e) {
  print('Login failed: $e');
}
```

**Old Logout:**
```dart
// Replace this
await authService.logout();
```

**New Logout:**
```dart
// With this
final authService = UnifiedAuthService();
await authService.logout();
```

### Step 3: Update API Clients

**Old API Client:**
```dart
// Replace this
final dio = Dio();
dio.interceptors.add(SomeAuthInterceptor());
```

**New API Client:**
```dart
// With this
import 'package:flutter_onegate/services/auth_service/secure_auth_interceptor.dart';

final dio = SecureDioFactory.createAuthenticatedDio(
  baseUrl: 'https://your-api.com',
);

// Now all API calls automatically handle tokens
final response = await dio.get('/api/user/profile');
```

### Step 4: Listen to Authentication State

```dart
import 'package:flutter_onegate/services/auth_service/unified_auth_service.dart';

class MyApp extends StatelessWidget {
  final authService = UnifiedAuthService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StreamBuilder<bool>(
        stream: authService.authStateStream,
        builder: (context, snapshot) {
          final isAuthenticated = snapshot.data ?? false;
          
          if (isAuthenticated) {
            return HomeScreen();
          } else {
            return LoginScreen();
          }
        },
      ),
    );
  }
}
```

## 🔧 Advanced Usage

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

### Check Authentication Status

```dart
final authService = UnifiedAuthService();
final isAuthenticated = await authService.isAuthenticated();

if (isAuthenticated) {
  final userInfo = await authService.getCurrentUser();
  print('Welcome ${userInfo?['name']}');
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

### Get Valid Access Token

```dart
final authService = UnifiedAuthService();
final token = await authService.getValidAccessToken();

if (token != null) {
  // Use token for API calls
  // Note: SecureAuthInterceptor does this automatically
}
```

## 🛠️ Configuration

### Token Refresh Timing

The system automatically calculates refresh timing based on JWT `exp` claims:
- Tokens refresh **2 minutes before expiry**
- If tokens expire within 2 minutes, immediate refresh is triggered
- Uses JWT `iat` (issued at) and `exp` (expiration) claims for precise timing

### Secure Storage

- **Android**: Encrypted SharedPreferences with Android Keystore
- **iOS**: Keychain with `first_unlock_this_device` accessibility

### HTTP Request Handling

The `SecureAuthInterceptor` automatically:
- Adds `Authorization: Bearer <token>` headers
- Skips auth for endpoints like `/auth/login`, `/auth/register`, `/public`
- Handles 401 responses with token refresh and retry (max 2 retries)
- Prevents infinite retry loops

## 🔍 Debugging

### Enable Debug Logging

All operations are logged with emojis for easy identification:
- 🔐 Authentication operations
- 🔄 Token refresh operations  
- 💾 Storage operations
- ⏰ Scheduling operations
- ❌ Errors
- ✅ Success operations

### Common Issues

**Issue: Session expired modal still appears**
- **Solution**: Ensure you're using `UnifiedAuthService` instead of old auth services

**Issue: Tokens not refreshing**
- **Solution**: Check that JWT tokens have valid `exp` claims and Keycloak is configured correctly

**Issue: 401 errors not handled**
- **Solution**: Use `SecureDioFactory.createAuthenticatedDio()` for all API clients

## 📋 Migration Checklist

- [ ] Replace `AuthService` with `UnifiedAuthService`
- [ ] Update login/logout flows
- [ ] Replace Dio instances with `SecureDioFactory.createAuthenticatedDio()`
- [ ] Remove old authentication interceptors
- [ ] Update authentication state listeners
- [ ] Test token refresh functionality
- [ ] Verify session persistence across app restarts

## 🧪 Testing

Run the test suite to verify everything works:

```bash
flutter test test/services/auth_service/secure_token_manager_test.dart
```

## 📚 Files Created

- `lib/services/auth_service/secure_token_manager.dart` - Core token management
- `lib/services/auth_service/unified_auth_service.dart` - Main authentication interface
- `lib/services/auth_service/secure_auth_interceptor.dart` - HTTP request interceptor
- `lib/services/auth_service/auth_integration_example.dart` - Usage examples
- `test/services/auth_service/secure_token_manager_test.dart` - Test suite

## 🎉 Benefits

- **No more session expired modals** during normal usage
- **Automatic token management** - set it and forget it
- **Secure token storage** with platform-specific encryption
- **Clean architecture** following hexagonal patterns
- **Comprehensive error handling** with graceful degradation
- **Thread-safe operations** preventing race conditions
- **Production-ready** with comprehensive testing
