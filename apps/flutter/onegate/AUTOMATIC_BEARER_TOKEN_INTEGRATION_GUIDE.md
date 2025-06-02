# Automatic Bearer Token Injection - Integration Guide

## 🎯 Overview

This guide documents the implementation of automatic Bearer token injection for all API requests in the OneGate Flutter app. The solution centralizes authentication header management through Dio interceptors while maintaining compatibility with the existing Keycloak authentication system.

## 🏗️ Architecture

### Core Components

1. **UnifiedAuthInterceptor** - Main interceptor for automatic token injection
2. **AuthenticatedDioFactory** - Factory for creating authenticated Dio instances
3. **SecureTokenManager** - Token storage and refresh management
4. **Enhanced API Services** - Updated service classes using the new system

### Key Features

- ✅ Automatic Bearer token injection for all authenticated requests
- ✅ Public endpoint detection and auth skipping
- ✅ 401 error handling with automatic token refresh and retry
- ✅ Integration with existing Keycloak authentication
- ✅ Clean architecture compliance
- ✅ Comprehensive error handling and logging

## 🔧 Implementation Details

### 1. UnifiedAuthInterceptor

**Location**: `lib/services/auth_service/unified_auth_interceptor.dart`

**Features**:
- Automatic Bearer token injection: `Authorization: Bearer {accessToken}`
- Token validation before each request
- 401 error handling with automatic retry (max 2 attempts)
- Public endpoint detection and auth skipping
- Comprehensive logging with emoji indicators

**Public Endpoints** (automatically skip authentication):
```dart
static const List<String> _skipAuthEndpoints = [
  '/auth/', '/login', '/logout', '/token', '/health', '/public/',
  '/gatelogin', '/sms/verification-code', '/visitor/selfCheckin', '/realms/',
];
```

### 2. AuthenticatedDioFactory

**Location**: `lib/services/api_client/authenticated_dio_factory.dart`

**Factory Methods**:
- `createAuthenticatedDio()` - General authenticated Dio instance
- `createOneGateApiClient()` - OneGate API with custom headers
- `createSocietyApiClient()` - Society API with predefined base URL
- `createFileUploadClient()` - Extended timeouts for file uploads
- `createPublicDio()` - No authentication for public endpoints
- `createRealtimeClient()` - Optimized for real-time communication

### 3. Updated Service Classes

**OneGateApiService**: Now uses `AuthenticatedDioFactory.createOneGateApiClient()`
**EnhancedRemoteDataSource**: Uses separate clients for Gate, Society, and Public APIs
**RemoteDataSource**: Enhanced with helper methods for authenticated clients

## 📊 API Endpoint Coverage

### Total Endpoints: 37

#### Authentication Endpoints (5) - Skip Auth
- `GET /realms/fstech/protocol/openid-connect/auth`
- `POST /realms/fstech/protocol/openid-connect/token`
- `GET /realms/fstech/protocol/openid-connect/userinfo`
- `POST /realms/fstech/protocol/openid-connect/logout`
- `POST /gatelogin`

#### Visitor Management Endpoints (11) - Require Auth
- `POST /visitor/entry`
- `GET /visitor/logs`
- `GET /visitor/log`
- `POST /visitor/checkout`
- `POST /visitor/sendLogs`
- `GET /visitor/requestApproval`
- `GET /visitor/getLog`
- `GET /visitor/approvals`
- `PUT /visitor/status/{visitorLogId}`
- `GET /visitor/parcelData/{companyId}`
- `POST /visitor/uploadFile`

#### Society & Building Management Endpoints (6) - Require Auth
- `GET /societies`
- `GET /admin/building/list`
- `GET /v2/admin/member/list`
- `GET /admin/units/list`
- `GET /admin/staffs/staffLists`
- `GET /members`

#### Gate Management Endpoints (2) - Require Auth
- `GET /admin/gates`
- `GET /gates`

#### Member & Access Endpoints (1) - Require Auth
- `POST /member/pass/verify`

#### Serverpod Endpoints (5) - Require Auth
- `purposeCategory.{method}`
- `visitor.fetchVisitor`
- `visitor.createVisitor`
- `visitor.updateVisitor`
- `visitorLog.{method}`

#### External Services (4) - Mixed Auth
- `GET /gate_facial_e7e469b505.json` (AWS S3 - Public)
- WebSocket events (Authenticated)
- `POST /logs` (Network logging - Authenticated)
- `GET /logs` (Network logging - Authenticated)

#### Internal Services (3) - Local/No Auth
- Crash reporting (Local storage)
- Analytics (Local storage)
- Data health checks (Uses existing APIs)

## 🚀 Usage Examples

### Basic API Call
```dart
// Automatic authentication - no manual token handling needed
final dio = AuthenticatedDioFactory.createOneGateApiClient(
  baseUrl: ApiUrls.gateBaseUrl,
);

final response = await dio.get('/visitor/logs');
// Authorization header automatically added
```

### Service Class Implementation
```dart
class MyApiService {
  late final Dio _apiClient;

  Future<void> initialize() async {
    _apiClient = AuthenticatedDioFactory.createOneGateApiClient(
      baseUrl: ApiUrls.gateBaseUrl,
      customHeaders: {'X-Service': 'MyApiService'},
    );
  }

  Future<List<dynamic>> fetchData() async {
    // Token automatically injected, 401 errors handled
    final response = await _apiClient.get('/api/data');
    return response.data;
  }
}
```

### Public Endpoint
```dart
// For public endpoints, use public Dio client
final publicDio = AuthenticatedDioFactory.createPublicDio(
  baseUrl: ApiUrls.gateBaseUrl,
);

final response = await publicDio.get('/sms/verification-code');
// No Authorization header added
```

## 🧪 Testing

### Test Coverage
- Unit tests for UnifiedAuthInterceptor
- Factory method tests for AuthenticatedDioFactory
- Integration tests for all 37 API endpoints
- Error handling and retry mechanism tests
- Public endpoint detection tests

### Running Tests
```bash
cd apps/flutter/onegate
flutter test test/services/auth_service/unified_auth_interceptor_test.dart
```

## 🔍 Debugging

### Logging Indicators
- 🔑 Bearer token added to request
- 🔓 Authentication skipped for public endpoint
- 🔄 Token refresh and request retry
- ⏰ Token expiration information
- ❌ Authentication errors
- ✅ Successful operations

### Common Issues

**Issue**: 401 errors still occurring
**Solution**: Verify token refresh is working and tokens are valid

**Issue**: Public endpoints receiving auth headers
**Solution**: Check endpoint path against skip list in UnifiedAuthInterceptor

**Issue**: Infinite retry loops
**Solution**: Verify max retry limit (2) is being enforced

## 📋 Migration Checklist

- ✅ UnifiedAuthInterceptor implemented
- ✅ AuthenticatedDioFactory created
- ✅ OneGateApiService updated
- ✅ EnhancedRemoteDataSource updated
- ✅ RemoteDataSource enhanced with helper methods
- ✅ Public endpoints properly identified
- ✅ Error handling and retry logic implemented
- ✅ Integration with existing SecureTokenManager
- ✅ Comprehensive test coverage
- ✅ Documentation and guides created

## 🔐 Security Considerations

- All tokens stored securely using flutter_secure_storage
- HTTPS enforced for all authenticated endpoints
- Token refresh uses rolling refresh tokens
- Automatic token cleanup on authentication failure
- No sensitive information logged in production

## 🎯 Benefits

1. **Centralized Authentication**: All token handling in one place
2. **Automatic Token Management**: No manual token injection needed
3. **Error Resilience**: Automatic 401 handling and retry
4. **Clean Architecture**: Maintains existing patterns
5. **Comprehensive Coverage**: All 37 endpoints properly handled
6. **Developer Experience**: Simple API for service classes
7. **Security**: Secure token storage and handling
8. **Maintainability**: Easy to update and extend

## 📚 Related Documentation

- [INTEGRATION_GUIDE.md](./INTEGRATION_GUIDE.md) - General integration guide
- [SECURE_AUTHENTICATION_GUIDE.md](./SECURE_AUTHENTICATION_GUIDE.md) - Security details
- [AUTHENTICATION_GUIDE.md](./AUTHENTICATION_GUIDE.md) - Authentication overview
