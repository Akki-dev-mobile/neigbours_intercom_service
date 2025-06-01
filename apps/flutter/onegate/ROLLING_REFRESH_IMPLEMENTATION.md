# Rolling Refresh Token Implementation - Indefinite Sessions

## 🎯 Overview

This implementation provides **true indefinite sessions** using the rolling refresh token pattern. Users will **NEVER** get automatically logged out or see session expired modals unless they explicitly logout.

## 🔄 How Rolling Refresh Tokens Work

### **The Magic Timeline:**
```
Time 0:00  - Login: Refresh token expires at 0:10
Time 0:03  - Access token refresh: NEW refresh token expires at 0:13
Time 0:06  - Access token refresh: NEW refresh token expires at 0:16  
Time 0:09  - Access token refresh: NEW refresh token expires at 0:19
Time 0:12  - Access token refresh: NEW refresh token expires at 0:22
...infinitely
```

### **Key Principle:**
- **Access tokens expire every 5 minutes** (short for security)
- **Refresh tokens expire every 10 minutes** (but get renewed)
- **Every 3 minutes** we refresh the access token
- **Each refresh gives us a NEW refresh token** with 10 more minutes
- **Result**: Infinite rolling window of authentication

## 🚀 Quick Implementation

### **Step 1: Replace Your Auth Service**

```dart
// OLD - Remove this
import 'package:flutter_onegate/services/auth_service/unified_auth_service.dart';
final authService = UnifiedAuthService();

// NEW - Use this instead
import 'package:flutter_onegate/services/auth_service/indefinite_session_manager.dart';
final authService = EnhancedUnifiedAuthService();
```

### **Step 2: Update main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_onegate/services/auth_service/indefinite_session_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the enhanced auth service with indefinite sessions
  final authService = EnhancedUnifiedAuthService();
  await authService.initialize();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final authService = EnhancedUnifiedAuthService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneGate',
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

### **Step 3: Update Your Login Screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_onegate/services/auth_service/indefinite_session_manager.dart';

class LoginScreen extends StatelessWidget {
  final authService = EnhancedUnifiedAuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              final userInfo = await authService.login();
              if (userInfo != null) {
                print('✅ Login successful: ${userInfo['name']}');
                // Navigation handled automatically by StreamBuilder
              }
            } catch (e) {
              print('❌ Login failed: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Login failed: $e')),
              );
            }
          },
          child: Text('Login with Keycloak'),
        ),
      ),
    );
  }
}
```

### **Step 4: Update Your Home Screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_onegate/services/auth_service/indefinite_session_manager.dart';

class HomeScreen extends StatelessWidget {
  final authService = EnhancedUnifiedAuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OneGate Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.info),
            onPressed: () => _showSessionInfo(context),
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await authService.logout();
              // Navigation handled automatically by StreamBuilder
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome to OneGate!'),
            SizedBox(height: 20),
            Text('You have indefinite session - no automatic logout!'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _testApiCall(),
              child: Text('Test API Call'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSessionInfo(BuildContext context) {
    final status = authService.getSessionStatus();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Session Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Indefinite Sessions: ${status['indefinite_sessions_enabled']}'),
            Text('Background Refresh: ${status['background_refresh_active']}'),
            Text('Consecutive Failures: ${status['consecutive_failures']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _testApiCall() async {
    // This will automatically use the secure token management
    final token = await authService.getValidAccessToken();
    if (token != null) {
      print('✅ Valid token available: ${token.substring(0, 20)}...');
    } else {
      print('❌ No valid token available');
    }
  }
}
```

### **Step 5: Update API Clients**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_onegate/services/auth_service/secure_auth_interceptor.dart';

class ApiService {
  static final Dio _dio = SecureDioFactory.createAuthenticatedDio(
    baseUrl: 'https://your-api-base-url.com',
  );

  // All API calls automatically handle token refresh
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final response = await _dio.get('/api/user/profile');
      return response.data;
    } catch (e) {
      print('API call failed: $e');
      return null;
    }
  }

  static Future<List<dynamic>?> getVisitors() async {
    try {
      final response = await _dio.get('/api/visitors');
      return response.data;
    } catch (e) {
      print('API call failed: $e');
      return null;
    }
  }
}
```

## 🔧 Keycloak Configuration

### **Required Settings for Rolling Refresh Tokens:**

#### **Realm Settings → Tokens:**
```
Access Token Lifespan: 5 minutes
Refresh Token Lifespan: 10 minutes (or longer)
Revoke Refresh Token: OFF
Refresh Token Max Reuse: 0 (unlimited)
```

#### **Realm Settings → Sessions:**
```
SSO Session Idle Timeout: [BLANK/DISABLED]
SSO Session Max Lifespan: [BLANK/DISABLED]
```

#### **Client Settings → Advanced:**
```
Use Refresh Tokens: ON
Use Refresh Tokens For Client Credentials Grant: ON
Access Token Lifespan: [INHERIT FROM REALM]
```

## 📊 Expected Behavior

### **✅ What Users Will Experience:**
- **Login once** and stay logged in indefinitely
- **No session expired modals** during normal usage
- **Seamless API calls** with automatic token management
- **App restarts** maintain login state
- **Background token refresh** every 2-3 minutes

### **🔄 Background Activity:**
```
[App starts] 🔐 Initializing enhanced auth service...
[Login] ✅ Login successful, enabling indefinite sessions
[2 min later] ⏰ Scheduling background refresh in 2 minutes
[Background] 🔄 Attempting background token refresh...
[Background] ✅ Background token refresh successful
[Background] ⏰ Scheduling next background refresh in 2 minutes
[Repeat indefinitely...]
```

### **🚪 When Users WILL Logout:**
1. **Manual logout** - User clicks logout button
2. **App uninstall** - Tokens are deleted
3. **Extended inactivity** - No app usage for longer than refresh token lifespan
4. **Network issues** - Extended network outage during critical refresh window
5. **Server-side revocation** - Admin revokes session in Keycloak

## 🔍 Monitoring & Debugging

### **Check Session Status:**
```dart
final authService = EnhancedUnifiedAuthService();
final status = authService.getSessionStatus();

print('Indefinite sessions: ${status['indefinite_sessions_enabled']}');
print('Background refresh: ${status['background_refresh_active']}');
print('Failures: ${status['consecutive_failures']}');
```

### **Force Token Refresh:**
```dart
final success = await authService.forceTokenRefresh();
print('Force refresh: ${success ? "Success" : "Failed"}');
```

### **Debug Logs to Watch:**
```
🔐 Initializing enhanced auth service...
✅ Enhanced auth service initialized
🔄 Enabling indefinite session management...
⏰ Scheduling next background refresh in 2 minutes
🔄 Attempting background token refresh...
✅ Background token refresh successful
```

## 🎉 Benefits

- **🔄 True indefinite sessions** - Login once, stay logged in
- **🛡️ Secure token rotation** - New tokens every 3 minutes
- **📱 Mobile-friendly** - Works like banking/social media apps
- **🔧 Zero maintenance** - Fully automated token management
- **⚡ High performance** - Background refresh doesn't block UI
- **🧪 Well tested** - Comprehensive test suite included

This implementation provides the ultimate user experience: **"Login once, stay logged in forever"** while maintaining security through continuous token rotation.
