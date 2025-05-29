# OneGate Authentication System Guide

This guide explains how to use the enhanced token-based authentication system in the OneGate Flutter application.

## 🏗️ Architecture Overview

The authentication system follows clean architecture principles with the following components:

### Core Services

1. **AuthService** - Handles Keycloak authentication, token management, and user sessions
2. **AuthenticatedApiClient** - Dio-based HTTP client with automatic token injection and refresh
3. **OneGateApiService** - High-level API service for OneGate backend operations
4. **UserSessionManager** - Manages user sessions, permissions, and role-based access

### Key Features

- ✅ **Automatic Token Refresh** - Tokens are automatically refreshed when expired
- ✅ **Role-Based Access Control** - Permission checking based on user roles
- ✅ **Session Management** - Real-time session state monitoring
- ✅ **Error Handling** - Comprehensive error handling with automatic retry
- ✅ **Clean Architecture** - Follows hexagonal/clean architecture patterns

## 🚀 Getting Started

### 1. Initialize Services

The services are automatically registered in the dependency injection container:

```dart
// Services are registered in lib/presentation/di/di.dart
setupLocator() {
  // Core services
  locator.registerLazySingleton<AuthService>(() => AuthService(...));
  locator.registerLazySingleton<AuthenticatedApiClient>(() => AuthenticatedApiClient());
  locator.registerLazySingleton<OneGateApiService>(() => OneGateApiService());
  locator.registerLazySingleton<UserSessionManager>(() => UserSessionManager());
}
```

### 2. Using the Authentication Service

```dart
import 'package:get_it/get_it.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';

class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = GetIt.I<AuthService>();
  }

  Future<void> _login() async {
    try {
      final userInfo = await _authService.login();
      if (userInfo != null) {
        // Login successful
        print('User logged in: ${userInfo['preferred_username']}');
      }
    } catch (e) {
      // Handle login error
      print('Login failed: $e');
    }
  }

  Future<void> _logout() async {
    try {
      await _authService.logout();
      // Logout successful
    } catch (e) {
      // Handle logout error
    }
  }
}
```

### 3. Making Authenticated API Calls

```dart
import 'package:flutter_onegate/services/api_service/onegate_api_service.dart';

class VisitorService {
  late final OneGateApiService _apiService;

  VisitorService() {
    _apiService = GetIt.I<OneGateApiService>();
  }

  Future<List<dynamic>> getVisitorLogs() async {
    try {
      // Automatically includes Bearer token and handles refresh
      final logs = await _apiService.getVisitorLogs(
        page: 1,
        limit: 20,
        status: 'pending',
      );
      return logs;
    } catch (e) {
      print('Error fetching visitor logs: $e');
      rethrow;
    }
  }

  Future<bool> createVisitor(Map<String, dynamic> visitorData) async {
    try {
      final result = await _apiService.createVisitorEntry(visitorData);
      return result != null;
    } catch (e) {
      print('Error creating visitor: $e');
      return false;
    }
  }
}
```

### 4. Session Management and Permissions

```dart
import 'package:flutter_onegate/services/session_manager/user_session_manager.dart';

class PermissionAwareWidget extends StatefulWidget {
  @override
  _PermissionAwareWidgetState createState() => _PermissionAwareWidgetState();
}

class _PermissionAwareWidgetState extends State<PermissionAwareWidget> {
  late final UserSessionManager _sessionManager;
  bool _canViewVisitors = false;
  bool _canApproveVisitors = false;

  @override
  void initState() {
    super.initState();
    _sessionManager = GetIt.I<UserSessionManager>();
    _checkPermissions();
    
    // Listen to session state changes
    _sessionManager.sessionStateStream.listen((state) {
      if (state == UserSessionState.unauthenticated) {
        // Handle logout
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  Future<void> _checkPermissions() async {
    final canView = await _sessionManager.hasPermission('view_visitors');
    final canApprove = await _sessionManager.hasPermission('approve_visitors');
    
    setState(() {
      _canViewVisitors = canView;
      _canApproveVisitors = canApprove;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_canViewVisitors)
          ElevatedButton(
            onPressed: () => _viewVisitors(),
            child: Text('View Visitors'),
          ),
        if (_canApproveVisitors)
          ElevatedButton(
            onPressed: () => _approveVisitor(),
            child: Text('Approve Visitor'),
          ),
      ],
    );
  }
}
```

## 🔐 Token Management

### Automatic Token Refresh

Tokens are automatically refreshed when:
- Making API calls with expired tokens
- Periodic background checks (every 5 minutes)
- Manual refresh requests

```dart
// Manual token refresh
final success = await _authService.refreshToken();
if (success) {
  print('Token refreshed successfully');
} else {
  print('Token refresh failed - user needs to re-authenticate');
}
```

### Token Storage

Tokens are stored securely using:
- **Flutter Secure Storage** - For sensitive tokens (access, refresh, ID tokens)
- **SharedPreferences** - For non-sensitive session data
- **Hive** - For structured user data and preferences

## 🎭 Role-Based Access Control

### Available Roles

- **admin/super_admin** - Full system access
- **gatekeeper** - Visitor management and approval
- **security** - Basic visitor operations
- **resident** - View own visitors only

### Permission System

```dart
// Check specific permission
final hasPermission = await _sessionManager.hasPermission('manage_users');

// Check multiple roles
final hasAnyRole = await _sessionManager.hasAnyRole(['admin', 'gatekeeper']);

// Get all user permissions
final permissions = await _sessionManager.getUserPermissions();
```

## 🔧 Error Handling

### Authentication Errors

```dart
try {
  await _apiService.getUserProfile();
} catch (e) {
  if (e.toString().contains('401')) {
    // Token expired or invalid
    final refreshed = await _authService.refreshToken();
    if (!refreshed) {
      // Redirect to login
      Navigator.pushReplacementNamed(context, '/login');
    }
  } else {
    // Other API errors
    _showErrorDialog(e.toString());
  }
}
```

### Network Errors

The `AuthenticatedApiClient` automatically handles:
- Connection timeouts
- Network connectivity issues
- Server errors (5xx)
- Token refresh on 401 errors

## 📱 Integration Examples

### Repository Pattern

```dart
class EnhancedVisitorRepository {
  late final OneGateApiService _apiService;
  late final UserSessionManager _sessionManager;

  Future<List<Visitor>> getVisitors() async {
    // Check permissions
    final hasPermission = await _sessionManager.hasPermission('view_visitors');
    if (!hasPermission) {
      throw Exception('Insufficient permissions');
    }

    // Make authenticated API call
    final response = await _apiService.getVisitorLogs();
    return response.map((json) => Visitor.fromJson(json)).toList();
  }
}
```

### BLoC Integration

```dart
class VisitorBloc extends Bloc<VisitorEvent, VisitorState> {
  final OneGateApiService _apiService;
  final UserSessionManager _sessionManager;

  VisitorBloc(this._apiService, this._sessionManager) : super(VisitorInitial()) {
    on<LoadVisitors>(_onLoadVisitors);
  }

  Future<void> _onLoadVisitors(LoadVisitors event, Emitter<VisitorState> emit) async {
    try {
      emit(VisitorLoading());
      
      // Check authentication
      final isAuthenticated = await _sessionManager.currentState == UserSessionState.authenticated;
      if (!isAuthenticated) {
        emit(VisitorError('User not authenticated'));
        return;
      }

      // Load visitors
      final visitors = await _apiService.getVisitorLogs();
      emit(VisitorLoaded(visitors));
    } catch (e) {
      emit(VisitorError(e.toString()));
    }
  }
}
```

## 🔍 Debugging

### Enable Debug Logging

The authentication system includes comprehensive logging:

```dart
// Logs are automatically enabled in debug mode
// Check console for detailed authentication flow logs:
// 🔐 Starting AppAuth login flow...
// 🔑 Access token received...
// ✅ Login completed successfully
```

### Session State Monitoring

```dart
// Monitor session state changes
_sessionManager.sessionStateStream.listen((state) {
  print('Session state changed: $state');
  switch (state) {
    case UserSessionState.authenticated:
      print('User is authenticated');
      break;
    case UserSessionState.tokenExpired:
      print('Token expired, refreshing...');
      break;
    case UserSessionState.unauthenticated:
      print('User logged out');
      break;
  }
});
```

## 🚀 Best Practices

1. **Always check permissions** before performing sensitive operations
2. **Handle authentication errors gracefully** with user-friendly messages
3. **Use the session manager** for real-time authentication state
4. **Leverage automatic token refresh** instead of manual token management
5. **Follow the repository pattern** for clean separation of concerns
6. **Monitor session state** for automatic logout handling

## 📚 API Reference

For detailed API documentation, see:
- `AuthService` - Core authentication operations
- `OneGateApiService` - High-level API operations
- `UserSessionManager` - Session and permission management
- `AuthenticatedApiClient` - Low-level HTTP client

## 🔧 Troubleshooting

### Common Issues

1. **Token refresh fails** - Check Keycloak client configuration
2. **Permission denied** - Verify user roles in Keycloak
3. **API calls fail** - Check network connectivity and server status
4. **Session not persisting** - Verify secure storage permissions

### Support

For additional support, check the authentication logs and ensure all services are properly initialized in the dependency injection container.
