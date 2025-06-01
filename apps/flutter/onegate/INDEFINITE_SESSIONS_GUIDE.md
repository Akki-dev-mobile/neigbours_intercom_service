# Indefinite Sessions Configuration Guide

## 🎯 Goal: Never Automatically Logout Users

This guide shows how to configure your OneGate app so users **never get automatically logged out** and **never see session expired modals** unless they explicitly logout.

## 🔧 Keycloak Server Configuration

### **Step 1: Realm Settings → Sessions**

```
SSO Session Idle Timeout: [LEAVE BLANK/DISABLED]
SSO Session Max Lifespan: [LEAVE BLANK/DISABLED]
```

**Why**: This prevents Keycloak from forcing logout due to inactivity or time limits.

### **Step 2: Realm Settings → Tokens**

```
Access Token Lifespan: 5 minutes (keep short for security)
Refresh Token Lifespan: 365 days (or maximum allowed)
Refresh Token Max Reuse: 0 (unlimited reuse)
```

**Why**: Long-lived refresh tokens ensure we can always get new access tokens.

### **Step 3: Client Settings → Advanced**

```
Access Token Lifespan: [LEAVE BLANK - inherits from realm]
Client Session Idle: [LEAVE BLANK/DISABLED]
Client Session Max: [LEAVE BLANK/DISABLED]
```

**Why**: Prevents client-specific session timeouts.

### **Step 4: Client Settings → Capability Config**

```
Client authentication: ON
Authorization: OFF
Standard flow: ON
Direct access grants: ON
```

**Why**: Ensures proper OAuth flow for token refresh.

## 💻 App Configuration

### **Step 1: Use Enhanced Auth Service**

Replace your current auth service initialization:

```dart
// OLD - Replace this
final authService = UnifiedAuthService();

// NEW - Use this instead
import 'package:flutter_onegate/services/auth_service/indefinite_session_manager.dart';

final authService = EnhancedUnifiedAuthService();
```

### **Step 2: Initialize in main.dart**

```dart
import 'package:flutter_onegate/services/auth_service/indefinite_session_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize enhanced auth service with indefinite sessions
  final authService = EnhancedUnifiedAuthService();
  await authService.initialize();
  
  runApp(MyApp());
}
```

### **Step 3: Update Your App Widget**

```dart
class MyApp extends StatelessWidget {
  final authService = EnhancedUnifiedAuthService();

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

## 🔄 How It Works

### **Aggressive Token Refresh Strategy**

1. **Every 2 minutes**: Automatically refresh access tokens in background
2. **Before expiry**: Refresh tokens 2 minutes before they expire
3. **Network failures**: Retry with exponential backoff (30s, 60s, 120s...)
4. **Never give up**: Continue trying even after multiple failures

### **Timeline Example**

```
Time 0:00  - Login successful
Time 0:02  - Background refresh #1 ✅
Time 0:04  - Background refresh #2 ✅
Time 0:06  - Background refresh #3 ✅
...
Time 24:00 - Still logged in (720 successful refreshes)
Time 48:00 - Still logged in (1440 successful refreshes)
```

### **Failure Handling**

```
Time 0:00  - Login successful
Time 0:02  - Background refresh fails ❌ (retry in 30s)
Time 0:02:30 - Retry #1 fails ❌ (retry in 60s)
Time 0:03:30 - Retry #2 succeeds ✅ (back to normal 2min cycle)
```

## 🛡️ Security Considerations

### **Why This Is Still Secure**

1. **Short-lived access tokens** (5 minutes) - limits exposure if compromised
2. **Encrypted token storage** - tokens stored securely on device
3. **Network security** - all requests over HTTPS
4. **Token rotation** - new tokens issued every refresh

### **When Users WILL Get Logged Out**

1. **Manual logout** - User clicks logout button
2. **App uninstall** - Tokens are deleted
3. **Device factory reset** - All data cleared
4. **Admin revokes session** - Server-side session termination
5. **Password change** - May invalidate refresh tokens (depends on Keycloak config)

## 🔍 Monitoring & Debugging

### **Check Session Status**

```dart
final authService = EnhancedUnifiedAuthService();
final status = authService.getSessionStatus();

print('Indefinite sessions enabled: ${status['indefinite_sessions_enabled']}');
print('Consecutive failures: ${status['consecutive_failures']}');
print('Background refresh active: ${status['background_refresh_active']}');
```

### **Force Token Refresh**

```dart
final authService = EnhancedUnifiedAuthService();
final success = await authService.forceTokenRefresh();

if (success) {
  print('✅ Force refresh successful');
} else {
  print('❌ Force refresh failed');
}
```

### **Debug Logs to Watch For**

**✅ Normal Operation:**
```
🔄 Enabling indefinite session management...
⏰ Scheduling next background refresh in 2 minutes
🔄 Attempting background token refresh...
✅ Background token refresh successful
```

**⚠️ Network Issues (Recoverable):**
```
⚠️ Token refresh failed (attempt 1/5)
⏰ Scheduling next background refresh in 30 seconds
🔄 Attempting background token refresh...
✅ Background token refresh successful
```

**❌ Persistent Issues:**
```
❌ Max refresh failures reached, but continuing to try...
⏰ Scheduling next background refresh in 5 minutes
```

## ⚙️ Advanced Configuration

### **Customize Refresh Intervals**

Edit `indefinite_session_manager.dart`:

```dart
// More aggressive (every 1 minute)
static const Duration _aggressiveRefreshInterval = Duration(minutes: 1);

// Less aggressive (every 5 minutes)
static const Duration _aggressiveRefreshInterval = Duration(minutes: 5);
```

### **Customize Retry Logic**

```dart
// More retries
static const int _maxRetryAttempts = 10;

// Faster retries
static const Duration _retryBackoffBase = Duration(seconds: 15);
```

### **Enable/Disable Indefinite Sessions**

```dart
final authService = EnhancedUnifiedAuthService();

// Disable indefinite sessions (back to normal behavior)
await authService.setIndefiniteSessionsEnabled(false);

// Re-enable indefinite sessions
await authService.setIndefiniteSessionsEnabled(true);
```

## 🎉 Expected Results

After implementing this configuration:

### **User Experience**
- ✅ Never see "Session Expired" modals
- ✅ Stay logged in across app restarts
- ✅ Stay logged in across device reboots
- ✅ Seamless experience like banking/social media apps

### **Technical Behavior**
- ✅ Tokens refresh every 2 minutes in background
- ✅ Automatic retry on network failures
- ✅ Persistent sessions until explicit logout
- ✅ Secure token storage and rotation

### **When Users Logout**
- 🚪 Only when they click "Logout" button
- 🚪 Only when app is uninstalled
- 🚪 Only when admin revokes session server-side

This configuration provides the ultimate "login once, stay logged in forever" experience while maintaining security through token rotation and secure storage.
