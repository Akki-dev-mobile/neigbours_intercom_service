# OneGate Persistent Authentication System

## 🎯 **Overview**

The OneGate Persistent Authentication System provides a "login once, stay logged in" experience similar to banking apps and social media platforms. Users authenticate once and remain logged in across app restarts, device reboots, and extended periods of inactivity until they explicitly log out.

## 🏗️ **Architecture**

### **Core Components**

1. **PersistentAuthenticationManager** - Main coordinator for persistent authentication
2. **PersistentAuthenticatedApiClient** - API client with automatic token management
3. **PersistentAuthIntegrationService** - Single entry point for all persistent auth functionality
4. **Enhanced Token Refresh Manager** - Automatic background token refresh
5. **Continuous Session Manager** - Session persistence across app lifecycle
6. **Session Timeout Override** - Disables idle timeouts for continuous sessions
7. **Background Session Manager** - Maintains authentication during app backgrounding

### **Key Features**

✅ **Automatic Token Refresh** - Tokens refreshed every 2 minutes in background
✅ **Session Persistence** - Authentication state preserved across app restarts
✅ **Seamless API Calls** - All API requests automatically include valid tokens
✅ **Background Management** - Token refresh continues when app is backgrounded
✅ **Health Monitoring** - Continuous health checks ensure system reliability
✅ **Graceful Degradation** - Handles authentication failures gracefully
✅ **Security First** - Uses secure storage and follows OAuth2/OIDC best practices

## 🚀 **Implementation**

### **1. Initialize in Main App**

```dart
import 'package:flutter_onegate/services/auth_service/persistent_auth_integration_service.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _persistentAuth = PersistentAuthIntegrationService();

  @override
  void initState() {
    super.initState();
    _initializePersistentAuth();
  }

  Future<void> _initializePersistentAuth() async {
    try {
      await _persistentAuth.initialize(
        apiBaseUrl: 'https://your-api-base-url.com',
        autoEnableOnLogin: true, // Automatically enable on login
      );
      print('✅ Persistent authentication initialized');
    } catch (e) {
      print('❌ Error initializing persistent authentication: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneGate',
      home: HomePage(),
    );
  }

  @override
  void dispose() {
    _persistentAuth.dispose();
    super.dispose();
  }
}
```

### **2. Register in Dependency Injection**

```dart
import 'package:get_it/get_it.dart';
import 'package:flutter_onegate/services/auth_service/persistent_auth_integration_service.dart';

void setupServiceLocator() {
  final getIt = GetIt.instance;
  
  // Register persistent authentication service
  getIt.registerSingleton<PersistentAuthIntegrationService>(
    PersistentAuthIntegrationService(),
  );
}
```

### **3. Use in Your App**

#### **Making API Calls**

```dart
import 'package:flutter_onegate/services/auth_service/persistent_auth_integration_service.dart';

class UserService {
  final _persistentAuth = PersistentAuthIntegrationService();

  Future<List<User>> getUsers() async {
    try {
      // API client automatically handles authentication
      final response = await _persistentAuth.apiClient.get('/api/users');
      return (response.data as List).map((json) => User.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching users: $e');
      rethrow;
    }
  }

  Future<User> createUser(User user) async {
    try {
      final response = await _persistentAuth.apiClient.post(
        '/api/users',
        data: user.toJson(),
      );
      return User.fromJson(response.data);
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }
}
```

#### **Monitoring Authentication Status**

```dart
import 'package:flutter_onegate/services/auth_service/persistent_auth_integration_service.dart';

class AuthStatusWidget extends StatefulWidget {
  @override
  _AuthStatusWidgetState createState() => _AuthStatusWidgetState();
}

class _AuthStatusWidgetState extends State<AuthStatusWidget> {
  final _persistentAuth = PersistentAuthIntegrationService();
  late StreamSubscription<PersistentAuthStatus> _statusSubscription;

  @override
  void initState() {
    super.initState();
    _statusSubscription = _persistentAuth.statusStream.listen((status) {
      setState(() {
        // Update UI based on status
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Status: ${_persistentAuth.currentStatus.description}'),
        if (_persistentAuth.isPersistentAuthActive)
          Icon(Icons.security, color: Colors.green)
        else
          Icon(Icons.security, color: Colors.grey),
      ],
    );
  }

  @override
  void dispose() {
    _statusSubscription.cancel();
    super.dispose();
  }
}
```

#### **Manual Control**

```dart
class AuthControlWidget extends StatelessWidget {
  final _persistentAuth = PersistentAuthIntegrationService();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () async {
            await _persistentAuth.enablePersistentAuthentication();
          },
          child: Text('Enable Persistent Auth'),
        ),
        ElevatedButton(
          onPressed: () async {
            await _persistentAuth.disablePersistentAuthentication();
          },
          child: Text('Disable Persistent Auth'),
        ),
        ElevatedButton(
          onPressed: () async {
            final refreshed = await _persistentAuth.forceTokenRefresh();
            print('Token refresh: ${refreshed ? 'Success' : 'Failed'}');
          },
          child: Text('Force Token Refresh'),
        ),
      ],
    );
  }
}
```

## 🔧 **Configuration**

### **Customization Options**

```dart
await _persistentAuth.initialize(
  apiBaseUrl: 'https://your-api.com',
  autoEnableOnLogin: true,  // Auto-enable on login
);

// Access individual components if needed
final manager = PersistentAuthenticationManager();
await manager.initialize();

// Configure API client separately
final apiClient = PersistentAuthenticatedApiClient();
await apiClient.initialize(
  baseUrl: 'https://your-api.com',
  connectTimeout: Duration(seconds: 30),
  receiveTimeout: Duration(seconds: 30),
);
```

### **Health Monitoring**

```dart
// Perform health check
final healthResults = await _persistentAuth.performHealthCheck();
print('Overall health: ${healthResults['overall']}');
print('Auth service: ${healthResults['authService']}');
print('API client: ${healthResults['apiClient']}');

// Get comprehensive status
final status = _persistentAuth.getComprehensiveStatus();
print('Detailed status: $status');

// Check time since last authentication
final timeSinceAuth = await _persistentAuth.getTimeSinceLastAuth();
print('Time since last auth: ${timeSinceAuth?.inHours} hours');
```

## 🔒 **Security Features**

### **Secure Token Storage**
- Uses Flutter Secure Storage with hardware encryption
- Tokens encrypted at rest on device
- Automatic token cleanup on logout

### **Automatic Token Refresh**
- Tokens refreshed 5 minutes before expiration
- Background refresh every 2 minutes
- Exponential backoff on refresh failures

### **Session Management**
- Session state persisted securely
- Automatic session restoration on app restart
- Health checks ensure session validity

### **API Security**
- All API calls automatically authenticated
- Automatic retry on 401 errors
- Token validation before each request

## 📊 **Monitoring & Debugging**

### **Logging**
All components provide detailed logging with emojis for easy identification:
- 🚀 Initialization
- 🔐 Authentication events
- 🔄 Token refresh operations
- 📱 App lifecycle events
- ✅ Success operations
- ❌ Error conditions

### **Status Monitoring**
```dart
// Listen to status changes
_persistentAuth.statusStream.listen((status) {
  switch (status) {
    case PersistentAuthStatus.active:
      print('✅ Persistent auth active');
      break;
    case PersistentAuthStatus.inactive:
      print('⚠️ Persistent auth inactive');
      break;
    case PersistentAuthStatus.error:
      print('❌ Persistent auth error');
      break;
  }
});
```

## 🎯 **Best Practices**

1. **Initialize Early** - Initialize persistent auth in main app startup
2. **Monitor Status** - Listen to status changes for UI updates
3. **Handle Errors** - Implement proper error handling for auth failures
4. **Use API Client** - Always use the persistent authenticated API client
5. **Health Checks** - Periodically perform health checks in production
6. **Logging** - Monitor logs for authentication issues
7. **Testing** - Test with various network conditions and app lifecycle scenarios

## 🔄 **Lifecycle Management**

The system automatically handles:
- **App Start** - Restores persistent authentication if previously enabled
- **App Background** - Continues token refresh in background
- **App Resume** - Validates and refreshes tokens immediately
- **Network Changes** - Adapts to connectivity changes
- **Token Expiration** - Automatic refresh before expiration
- **Authentication Failures** - Graceful handling and user notification

This implementation provides a seamless, secure, and reliable persistent authentication experience that keeps users logged in while maintaining the highest security standards.
