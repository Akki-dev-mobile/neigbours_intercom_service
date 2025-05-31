# OneGate Riverpod Authentication System

This directory contains a production-ready Riverpod-based authentication system for OneGate that provides silent token refresh without forcing logout.

## 🏗️ Architecture Overview

The authentication system follows clean architecture principles with these core components:

### Core Components

1. **AuthTokens** - Immutable data class for authentication tokens
2. **AuthStorage** - Secure storage wrapper using flutter_secure_storage
3. **AuthState** - Freezed union type representing authentication states
4. **AuthController** - Riverpod controller managing authentication logic
5. **AuthInterceptor** - Dio interceptor for automatic token injection and refresh

### Key Features

- ✅ **Silent Token Refresh** - Automatically refreshes tokens without user intervention
- ✅ **Scheduled Auto-Refresh** - Proactively refreshes tokens 2 minutes before expiration
- ✅ **401 Error Handling** - Automatically retries failed requests after token refresh
- ✅ **Secure Storage** - Uses flutter_secure_storage for token persistence
- ✅ **Clean Architecture** - Follows hexagonal architecture patterns
- ✅ **Comprehensive Testing** - Unit tests for all critical paths
- ✅ **Type Safety** - Full type safety with Freezed and Riverpod

## 🚀 Quick Start

### 1. Wrap your app with ProviderScope

```dart
void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### 2. Use AuthStateWidget to handle authentication states

```dart
class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      home: AuthStateWidget(
        child: YourMainScreen(),
      ),
    );
  }
}
```

### 3. Make authenticated API calls

```dart
class ApiService {
  final Dio _dio;
  
  ApiService(this._dio);
  
  Future<Map<String, dynamic>> getUserProfile() async {
    // Token injection and refresh handled automatically
    final response = await _dio.get('/api/user/profile');
    return response.data;
  }
}

// Usage with Riverpod
final apiServiceProvider = Provider<ApiService>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiService(dio);
});
```

## 📋 Integration Guide

### Step 1: Update main.dart

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/auth_service/riverpod/riverpod_auth_integration.dart';

void main() {
  runApp(
    ProviderScope(
      child: AuthenticatedApp(),
    ),
  );
}
```

### Step 2: Replace existing authentication

Replace your existing Provider-based authentication with the new Riverpod system:

```dart
// Old way
ChangeNotifierProvider<LoginProvider>(
  create: (_) => LoginProvider(authService: GetIt.I<AuthService>()),
),

// New way - no need to register, Riverpod handles it
// Just use ref.watch(authControllerProvider) in your widgets
```

### Step 3: Update API clients

```dart
// Old way
final dio = GetIt.I<Dio>();
dio.interceptors.add(EnhancedAuthInterceptor(...));

// New way
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();
  dio.interceptors.add(AuthInterceptorFactory.create(ref));
  return dio;
});
```

## 🔧 Configuration

### Token Refresh Timing

The system automatically calculates optimal refresh timing:
- Tokens are refreshed 2 minutes before expiration
- If tokens expire within 2 minutes, immediate refresh is triggered
- Failed refresh attempts result in automatic logout

### Secure Storage

Tokens are stored using flutter_secure_storage with:
- Android: Encrypted SharedPreferences
- iOS: Keychain with first_unlock_this_device accessibility

### Error Handling

- **401 Errors**: Automatically refresh token and retry request
- **Refresh Failures**: Logout user and redirect to login
- **Network Errors**: Graceful degradation with user feedback

## 🧪 Testing

Run the comprehensive test suite:

```bash
flutter test test/services/auth_service/riverpod/
```

### Test Coverage

- ✅ Scheduled auto-refresh functionality
- ✅ 401 → refresh → retry success path
- ✅ 401 → refresh failure → logout path
- ✅ Concurrent request handling
- ✅ Token storage and retrieval
- ✅ Authentication state management

## 🔄 Migration from Existing System

### 1. Gradual Migration

You can run both systems side by side during migration:

```dart
// Keep existing Provider system
ChangeNotifierProvider<LoginProvider>(...),

// Add new Riverpod system
// Use ref.watch(authControllerProvider) in new widgets
```

### 2. API Client Migration

```dart
// Migrate API clients one by one
final legacyApiClient = GetIt.I<AuthenticatedApiClient>();
final newApiClient = ref.watch(apiServiceProvider);
```

### 3. State Synchronization

If needed, you can synchronize states between systems during migration:

```dart
ref.listen(authControllerProvider, (previous, next) {
  // Sync with legacy system if needed
  if (next.isAuthenticated) {
    // Update legacy providers
  }
});
```

## 📚 API Reference

### AuthController Methods

- `login()` - Perform OAuth login with Keycloak
- `logout()` - Clear tokens and logout user
- `refreshToken()` - Manually refresh access token
- `isAuthenticated` - Check authentication status
- `accessToken` - Get current access token

### AuthState Types

- `UnauthenticatedState` - User not logged in
- `LoadingState` - Authentication in progress
- `AuthenticatedState` - User logged in with valid tokens
- `ErrorState` - Authentication error occurred

### AuthInterceptor Features

- Automatic token injection
- 401 error handling with retry
- Concurrent request management
- Configurable retry limits

## 🛡️ Security Considerations

- Tokens stored in secure storage only
- Automatic token cleanup on logout
- No token exposure in logs (production)
- PKCE support for OAuth flows
- Secure HTTP-only communication

## 🔍 Debugging

Enable debug mode to see detailed authentication logs:

```dart
// Logs will show:
// 🔐 Login process steps
// 🔄 Token refresh operations
// 🔑 Token injection events
// ⏰ Scheduled refresh timing
// ❌ Error details and recovery
```

## 📈 Performance

- Minimal memory footprint
- Efficient token refresh scheduling
- Concurrent request deduplication
- Fast secure storage operations
- Optimized for mobile performance

## 🤝 Contributing

When contributing to the authentication system:

1. Maintain backward compatibility
2. Add comprehensive tests
3. Update documentation
4. Follow clean architecture principles
5. Ensure type safety with Freezed/Riverpod
