# Enhanced Authentication System Guide

This guide explains the enhanced automatic refresh token logic implemented in the OneGate Flutter app's authentication system.

## 🚀 Overview

The enhanced authentication system provides seamless, automatic token refresh capabilities that work transparently in the background without requiring user intervention. The system follows clean architecture and hexagonal patterns while ensuring thread-safe operations.

## 🏗️ Architecture Components

### 1. **JwtTokenUtility**
- **Location**: `lib/services/auth_service/jwt_token_utility.dart`
- **Purpose**: Provides comprehensive JWT token parsing and validation utilities
- **Key Features**:
  - Parse JWT tokens and extract claims
  - Detect token expiration with configurable buffer time
  - Extract user information from tokens
  - Validate token structure and integrity

### 2. **EnhancedTokenRefreshManager**
- **Location**: `lib/services/auth_service/enhanced_token_refresh_manager.dart`
- **Purpose**: Centralized token refresh management with automatic capabilities
- **Key Features**:
  - Singleton pattern for thread-safe operations
  - Automatic token refresh 5 minutes before expiration
  - Periodic background token validation checks
  - Retry logic with exponential backoff
  - Concurrency control to prevent multiple simultaneous refreshes

### 3. **EnhancedAuthInterceptor**
- **Location**: `lib/services/auth_service/enhanced_auth_interceptor.dart`
- **Purpose**: Dio interceptor for automatic token injection and refresh on API calls
- **Key Features**:
  - Automatic Bearer token injection
  - 401 error handling with token refresh and request retry
  - Configurable retry attempts and delays
  - Authentication failure handling

### 4. **Enhanced AuthService**
- **Location**: `lib/services/auth_service/auth_service.dart` (updated)
- **Purpose**: Main authentication service with enhanced token management
- **Key Features**:
  - Integration with EnhancedTokenRefreshManager
  - Improved JWT token parsing using JwtTokenUtility
  - Enhanced logout with proper token cleanup

## 🔧 Configuration

### Token Refresh Settings
```dart
// Default configuration in EnhancedTokenRefreshManager
static const Duration _refreshBuffer = Duration(minutes: 5);
static const Duration _refreshCheckInterval = Duration(minutes: 1);
static const int _maxRetryAttempts = 3;
static const Duration _retryDelay = Duration(seconds: 5);
```

### Request Retry Settings
```dart
// Default configuration in EnhancedAuthInterceptor
static const int _maxRetryAttempts = 2;
static const Duration _retryDelay = Duration(milliseconds: 500);
```

## 📱 Usage Examples

### 1. Basic API Call with Automatic Token Management
```dart
// The enhanced system handles token refresh automatically
final apiClient = GetIt.I<AuthenticatedApiClient>();
final response = await apiClient.get('/api/visitors');
// Token is automatically refreshed if needed before the request
```

### 2. Manual Token Validation
```dart
final authService = GetIt.I<AuthService>();
final tokenManager = authService.tokenRefreshManager;

// Get a valid token (refreshes automatically if needed)
final token = await tokenManager.getValidAccessToken();

// Check if refresh token is still valid
final isRefreshValid = await tokenManager.isRefreshTokenValid();
```

### 3. JWT Token Analysis
```dart
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';

// Parse and analyze a JWT token
final userInfo = JwtTokenUtility.getUserInfoFromToken(accessToken);
print('User: ${userInfo?['name']}');
print('Roles: ${userInfo?['roles']}');

// Check token expiration
final isExpiring = JwtTokenUtility.isTokenExpiredOrExpiring(
  accessToken,
  buffer: Duration(minutes: 5),
);
```

### 4. Custom Request Options
```dart
import 'package:flutter_onegate/services/auth_service/enhanced_auth_interceptor.dart';

// Enable token debugging for a specific request
final options = Options();
options.enableTokenDebug();

// Skip authentication for a public endpoint
final publicOptions = Options();
publicOptions.setSkipAuth();

final response = await apiClient.get('/public/data', options: publicOptions);
```

## 🔄 Automatic Refresh Flow

### 1. **Proactive Refresh**
- Background timer checks tokens every minute
- Automatically refreshes tokens 5 minutes before expiration
- No user interaction required

### 2. **Reactive Refresh**
- API calls automatically check token validity
- 401 responses trigger immediate token refresh
- Failed requests are automatically retried with new tokens

### 3. **Concurrency Control**
- Multiple simultaneous refresh requests are handled safely
- Only one refresh operation runs at a time
- Waiting requests receive the result of the ongoing refresh

## 🛡️ Error Handling

### 1. **Token Refresh Failures**
```dart
// Automatic retry with exponential backoff
// After max attempts, user is redirected to login
```

### 2. **Network Errors**
```dart
// Connection timeouts and network errors are handled gracefully
// Appropriate error messages are logged for debugging
```

### 3. **Invalid Refresh Tokens**
```dart
// Expired refresh tokens trigger automatic logout
// User is redirected to login screen
```

## 🧪 Testing

### Running Tests
```bash
# Run all authentication tests
flutter test test/services/auth_service/

# Run specific enhanced token refresh tests
flutter test test/services/auth_service/enhanced_token_refresh_test.dart
```

### Test Coverage
- JWT token parsing and validation
- Token expiration detection
- Concurrent refresh request handling
- Error scenarios and edge cases
- Token cleanup on logout

## 🔍 Debugging

### Enable Debug Logging
```dart
// Enable token debugging for specific requests
final options = Options();
options.enableTokenDebug();
```

### Log Analysis
- Look for `🔄` symbols for token refresh operations
- Look for `🔑` symbols for token injection
- Look for `❌` symbols for errors
- Look for `✅` symbols for successful operations

## 🚨 Security Considerations

### 1. **Token Storage**
- Access tokens stored in Flutter Secure Storage
- Refresh tokens encrypted and stored securely
- Tokens are cleared on logout and app uninstall

### 2. **Network Security**
- All token operations use HTTPS
- Bearer tokens are transmitted securely
- No tokens are logged in production builds

### 3. **Token Lifecycle**
- Automatic cleanup of expired tokens
- Secure token refresh process
- Proper session management

## 📊 Performance Optimizations

### 1. **Efficient Token Checks**
- JWT parsing is cached where possible
- Minimal network calls for token validation
- Background refresh reduces API call latency

### 2. **Memory Management**
- Singleton pattern prevents memory leaks
- Proper disposal of timers and resources
- Efficient token storage and retrieval

### 3. **Network Optimization**
- Request retry logic reduces failed API calls
- Automatic token refresh prevents 401 errors
- Concurrent request handling improves performance

## 🔧 Troubleshooting

### Common Issues

1. **Token Refresh Loops**
   - Check refresh token validity
   - Verify Keycloak configuration
   - Review network connectivity

2. **Authentication Failures**
   - Verify client credentials
   - Check token expiration settings
   - Review server-side configuration

3. **Performance Issues**
   - Monitor background refresh frequency
   - Check for memory leaks
   - Review network request patterns

### Debug Commands
```dart
// Log current token status
JwtTokenUtility.logTokenDetails("ACCESS", accessToken);

// Check if refresh token is valid
final isRefreshValid = await tokenManager.isRefreshTokenValid();

// Verify service registration
final authService = GetIt.I<AuthService>();

// Enable debug logging for specific requests
final options = Options();
options.enableTokenDebug();
```

## 🔄 Migration Guide

### From Old Authentication System

1. **Update Service Registration**:
```dart
// Old way
locator.registerLazySingleton<AuthService>(() => AuthService(...));

// New way (already implemented)
locator.registerLazySingleton<EnhancedTokenRefreshManager>(() => EnhancedTokenRefreshManager());
locator.registerLazySingleton<AuthService>(() => AuthService(...));
```

2. **Update API Client Usage**:
```dart
// Old way - manual token management
final token = await authService.getAccessToken();
if (await gateStorage.isTokenExpired()) {
  await authService.refreshToken();
}

// New way - automatic token management
final response = await apiClient.get('/api/endpoint');
// Token refresh is handled automatically
```

3. **Update Error Handling**:
```dart
// Old way - manual 401 handling
try {
  final response = await apiClient.get('/api/endpoint');
} catch (e) {
  if (e is DioException && e.response?.statusCode == 401) {
    await authService.refreshToken();
    // Retry manually
  }
}

// New way - automatic retry
final response = await apiClient.get('/api/endpoint');
// 401 errors are handled automatically with retry
```

## 🎯 Best Practices

1. **Always use AuthenticatedApiClient** for API calls
2. **Don't manually manage tokens** - let the system handle it
3. **Handle authentication failures** gracefully in your UI
4. **Test token refresh scenarios** thoroughly
5. **Monitor token refresh logs** in production
6. **Keep refresh buffer time** reasonable (5 minutes recommended)

## 📈 Future Enhancements

- Token refresh analytics and monitoring
- Advanced retry strategies
- Token preemptive refresh based on usage patterns
- Integration with biometric authentication
- Enhanced security features
