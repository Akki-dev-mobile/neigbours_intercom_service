# Token Debugging Guide - Keycloak & Flutter

## 🔍 How to Debug Token Issues

This guide helps you identify whether token refresh issues are coming from the Flutter app or Keycloak backend.

## 🧪 Step-by-Step Debugging Process

### **Step 1: Decode Your Current Tokens**

Add this debug function to your Flutter app:

```dart
void debugCurrentTokens() async {
  final authService = EnhancedUnifiedAuthService();
  
  // Get current access token
  final accessToken = await authService.getValidAccessToken();
  if (accessToken != null) {
    final payload = JwtTokenUtility.parseJwtToken(accessToken);
    
    print('🔍 === CURRENT TOKEN DEBUG ===');
    print('Access Token:');
    print('  iat (issued): ${_formatTimestamp(payload['iat'])}');
    print('  exp (expires): ${_formatTimestamp(payload['exp'])}');
    print('  auth_time: ${_formatTimestamp(payload['auth_time'])}');
    print('  Time until expiry: ${_getTimeUntilExpiry(payload['exp'])} minutes');
    print('================================');
  }
}

String _formatTimestamp(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  return '${date.toString()} (${timestamp})';
}

double _getTimeUntilExpiry(int exp) {
  final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
  final now = DateTime.now();
  return expiry.difference(now).inMinutes.toDouble();
}
```

### **Step 2: Monitor Token Refresh in Real-Time**

```dart
void startTokenMonitoring() {
  Timer.periodic(Duration(minutes: 1), (_) async {
    final authService = EnhancedUnifiedAuthService();
    final token = await authService.getValidAccessToken();
    
    if (token != null) {
      final payload = JwtTokenUtility.parseJwtToken(token);
      final exp = DateTime.fromMillisecondsSinceEpoch(payload['exp'] * 1000);
      final iat = DateTime.fromMillisecondsSinceEpoch(payload['iat'] * 1000);
      
      print('🕐 ${DateTime.now().toString().substring(11, 19)} | '
            'Token issued: ${iat.toString().substring(11, 19)} | '
            'Expires: ${exp.toString().substring(11, 19)}');
    }
  });
}
```

### **Step 3: Test Manual Token Refresh**

```dart
Future<void> testManualRefresh() async {
  final authService = EnhancedUnifiedAuthService();
  
  print('🔄 === MANUAL REFRESH TEST ===');
  
  // Get token before refresh
  final beforeToken = await authService.getValidAccessToken();
  final beforePayload = JwtTokenUtility.parseJwtToken(beforeToken!);
  print('BEFORE - exp: ${beforePayload['exp']} (${_formatTimestamp(beforePayload['exp'])})');
  
  // Force refresh
  final success = await authService.forceTokenRefresh();
  print('Refresh result: ${success ? "SUCCESS" : "FAILED"}');
  
  // Get token after refresh
  final afterToken = await authService.getValidAccessToken();
  final afterPayload = JwtTokenUtility.parseJwtToken(afterToken!);
  print('AFTER  - exp: ${afterPayload['exp']} (${_formatTimestamp(afterPayload['exp'])})');
  
  // Compare
  if (beforePayload['exp'] == afterPayload['exp']) {
    print('❌ PROBLEM: Same expiry time - Keycloak configuration issue');
  } else {
    print('✅ SUCCESS: New expiry time - Rolling refresh working');
  }
  
  print('===============================');
}
```

## 🔧 Backend Testing with Postman/cURL

### **Test 1: Direct Token Refresh**

```bash
# Replace with your actual values
curl -X POST "https://your-keycloak.com/realms/your-realm/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "refresh_token=YOUR_REFRESH_TOKEN" \
  -d "client_id=YOUR_CLIENT_ID" \
  -d "client_secret=YOUR_CLIENT_SECRET"
```

### **Test 2: Decode Response Tokens**

Use [jwt.io](https://jwt.io) to decode the returned access token and check:

1. **iat (issued at)** - Should be current time
2. **exp (expires at)** - Should be iat + 5 minutes (or your token lifespan)
3. **Compare with previous token** - exp should be different

## 📊 Diagnostic Scenarios

### **Scenario 1: Fixed Expiry Time (Keycloak Issue)**

```json
// First token (login at 16:25)
{"iat": 1748775883, "exp": 1748775946}  // Expires at 16:32

// Second token (refresh at 16:28)  
{"iat": 1748775718, "exp": 1748775946}  // SAME expiry ❌
```

**Diagnosis:** Keycloak session settings are overriding token refresh.
**Fix:** Clear SSO Session Idle/Max settings in Keycloak.

### **Scenario 2: Rolling Expiry (Working Correctly)**

```json
// First token (login at 16:25)
{"iat": 1748775883, "exp": 1748775946}  // Expires at 16:32

// Second token (refresh at 16:28)
{"iat": 1748775718, "exp": 1748776126}  // NEW expiry at 16:35 ✅
```

**Diagnosis:** Rolling refresh working correctly.
**Result:** Indefinite sessions achieved.

### **Scenario 3: Refresh Failure (Network/Config Issue)**

```
🔄 Starting token refresh...
❌ Token refresh failed: No refresh token available
```

**Diagnosis:** Refresh token expired or invalid.
**Fix:** Check refresh token lifespan and app idle time.

## 🛠️ Flutter Debug Integration

Add this to your app's debug menu:

```dart
class TokenDebugScreen extends StatefulWidget {
  @override
  _TokenDebugScreenState createState() => _TokenDebugScreenState();
}

class _TokenDebugScreenState extends State<TokenDebugScreen> {
  final authService = EnhancedUnifiedAuthService();
  String _debugInfo = 'Tap buttons to debug tokens';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Token Debug')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_debugInfo, style: TextStyle(fontFamily: 'monospace')),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _debugCurrentToken,
              child: Text('Debug Current Token'),
            ),
            ElevatedButton(
              onPressed: _testManualRefresh,
              child: Text('Test Manual Refresh'),
            ),
            ElevatedButton(
              onPressed: _startMonitoring,
              child: Text('Start Real-time Monitoring'),
            ),
            ElevatedButton(
              onPressed: _checkSessionStatus,
              child: Text('Check Session Status'),
            ),
          ],
        ),
      ),
    );
  }

  void _debugCurrentToken() async {
    final token = await authService.getValidAccessToken();
    if (token != null) {
      final payload = JwtTokenUtility.parseJwtToken(token);
      setState(() {
        _debugInfo = '''
🔍 CURRENT TOKEN:
iat: ${_formatTimestamp(payload['iat'])}
exp: ${_formatTimestamp(payload['exp'])}
Minutes until expiry: ${_getTimeUntilExpiry(payload['exp'])}
        ''';
      });
    }
  }

  void _testManualRefresh() async {
    final beforeToken = await authService.getValidAccessToken();
    final beforePayload = JwtTokenUtility.parseJwtToken(beforeToken!);
    
    final success = await authService.forceTokenRefresh();
    
    final afterToken = await authService.getValidAccessToken();
    final afterPayload = JwtTokenUtility.parseJwtToken(afterToken!);
    
    setState(() {
      _debugInfo = '''
🔄 REFRESH TEST:
Before exp: ${beforePayload['exp']}
After exp:  ${afterPayload['exp']}
Success: $success
Same expiry: ${beforePayload['exp'] == afterPayload['exp'] ? "❌ PROBLEM" : "✅ GOOD"}
      ''';
    });
  }

  void _startMonitoring() {
    Timer.periodic(Duration(seconds: 30), (_) async {
      final token = await authService.getValidAccessToken();
      if (token != null && mounted) {
        final payload = JwtTokenUtility.parseJwtToken(token);
        final exp = DateTime.fromMillisecondsSinceEpoch(payload['exp'] * 1000);
        setState(() {
          _debugInfo = '''
🕐 MONITORING:
Current time: ${DateTime.now().toString().substring(11, 19)}
Token expires: ${exp.toString().substring(11, 19)}
Minutes left: ${_getTimeUntilExpiry(payload['exp'])}
          ''';
        });
      }
    });
  }

  void _checkSessionStatus() {
    final status = authService.getSessionStatus();
    setState(() {
      _debugInfo = '''
📊 SESSION STATUS:
Indefinite sessions: ${status['indefinite_sessions_enabled']}
Background refresh: ${status['background_refresh_active']}
Consecutive failures: ${status['consecutive_failures']}
      ''';
    });
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return date.toString().substring(11, 19);
  }

  double _getTimeUntilExpiry(int exp) {
    final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    return expiry.difference(DateTime.now()).inMinutes.toDouble();
  }
}
```

## 🎯 Quick Diagnosis Checklist

### **✅ Working Correctly:**
- [ ] Each token refresh shows NEW expiry time
- [ ] Expiry time = current time + token lifespan
- [ ] No automatic logout during normal usage
- [ ] Background refresh logs show success

### **❌ Keycloak Configuration Issue:**
- [ ] Same expiry time after refresh
- [ ] Logout exactly at session idle timeout
- [ ] All tokens expire at same fixed time
- [ ] Session settings not blank in Keycloak

### **❌ Flutter Implementation Issue:**
- [ ] No refresh attempts in logs
- [ ] Refresh fails with network errors
- [ ] Tokens not stored properly
- [ ] Background refresh not running

## 🔧 Common Fixes

### **For Keycloak Issues:**
1. Clear SSO Session Idle/Max settings
2. Set Revoke Refresh Token to OFF
3. Set Refresh Token Max Reuse to 0
4. Restart Keycloak server

### **For Flutter Issues:**
1. Check network connectivity
2. Verify Keycloak client configuration
3. Ensure background refresh is enabled
4. Check secure storage permissions

This debugging approach will quickly identify whether the issue is in your Flutter app or Keycloak configuration.
