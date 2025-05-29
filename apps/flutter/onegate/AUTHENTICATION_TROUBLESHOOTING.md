# OneGate Authentication Troubleshooting Guide

This guide helps troubleshoot flutter_appauth authentication issues in the OneGate Flutter application.

## 🚨 Common Issues and Solutions

### Issue 1: "unauthorized_client" Error

**Symptoms:**
- Login fails with "unauthorized_client" error
- Authentication flow doesn't complete

**Root Causes:**
1. Client ID doesn't exist in Keycloak
2. Client is disabled in Keycloak
3. Redirect URI not registered
4. Client access type mismatch

**Solutions:**

#### ✅ Keycloak Client Configuration Checklist
```
□ Client ID: "onegate-sso" exists in realm "fstech"
□ Client Status: Enabled = true
□ Access Type: Public or Confidential (match your app config)
□ Standard Flow Enabled: true
□ Direct Access Grants Enabled: true
□ Valid Redirect URIs: "com.cubeonebiz.gate://login-callback"
□ Web Origins: "*" or specific origins
```

#### ✅ Fix Steps:
1. **Verify Client Exists:**
   ```
   Keycloak Admin Console → Realms → fstech → Clients → onegate-sso
   ```

2. **Check Client Settings:**
   ```
   Settings Tab:
   - Client ID: onegate-sso
   - Enabled: ON
   - Client Protocol: openid-connect
   - Access Type: public (recommended) or confidential
   - Standard Flow Enabled: ON
   - Direct Access Grants Enabled: ON
   ```

3. **Configure Redirect URIs:**
   ```
   Valid Redirect URIs: com.cubeonebiz.gate://login-callback
   Valid Post Logout Redirect URIs: com.cubeonebiz.gate://logout-callback
   Web Origins: *
   ```

### Issue 2: "invalid_client" Error

**Symptoms:**
- Authentication fails with "invalid_client"
- Token exchange fails

**Root Causes:**
1. Client secret mismatch (confidential clients)
2. Client configuration issues
3. PKCE configuration problems

**Solutions:**

#### ✅ For Confidential Clients:
1. **Verify Client Secret:**
   ```dart
   // In enhanced_keycloak_config.dart
   static const String clientSecret = 'your-actual-client-secret';
   ```

2. **Get Client Secret from Keycloak:**
   ```
   Keycloak Admin Console → Clients → onegate-sso → Credentials Tab
   Copy the Secret value
   ```

#### ✅ For Public Clients (Recommended):
1. **Switch to Public Client:**
   ```
   Keycloak: Access Type = public
   App: Remove or empty clientSecret
   ```

2. **Enable PKCE:**
   ```
   Keycloak Client Settings:
   - Proof Key for Code Exchange Code Challenge Method: S256
   ```

### Issue 3: Redirect URI Mismatch

**Symptoms:**
- Browser opens but doesn't return to app
- "redirect_uri_mismatch" error

**Root Causes:**
1. Redirect URI not registered in Keycloak
2. Android manifest not configured
3. Bundle identifier mismatch

**Solutions:**

#### ✅ Android Manifest Configuration:
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme">
    
    <!-- Existing intent filters -->
    
    <!-- Add this for OAuth redirect -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="com.cubeonebiz.gate" />
    </intent-filter>
</activity>
```

#### ✅ Keycloak Redirect URI:
```
Valid Redirect URIs: com.cubeonebiz.gate://login-callback
```

### Issue 4: PKCE Configuration Issues

**Symptoms:**
- "pkce_verification_failed" error
- Token exchange fails

**Solutions:**

#### ✅ Enable PKCE in Keycloak:
```
Client Settings → Advanced Settings:
- Proof Key for Code Exchange Code Challenge Method: S256
```

#### ✅ App Configuration:
```dart
// PKCE is automatically handled by flutter_appauth
// No additional configuration needed
```

### Issue 5: Network/SSL Issues

**Symptoms:**
- Connection timeouts
- SSL certificate errors
- Network unreachable

**Solutions:**

#### ✅ For Development (Self-signed certificates):
```dart
// In enhanced_keycloak_config.dart
if (kDebugMode) {
  HttpOverrides.global = _MyHttpOverrides();
}
```

#### ✅ Check Network Connectivity:
```bash
# Test Keycloak server
curl https://stgsso.cubeone.in/realms/fstech/.well-known/openid_configuration

# Test specific endpoints
curl https://stgsso.cubeone.in/realms/fstech/protocol/openid-connect/auth
```

## 🔧 Debugging Tools

### 1. Use the Debug Widget
```dart
// Add to your app for testing
import 'package:flutter_onegate/presentation/widgets/auth_debug_widget.dart';

// Navigate to debug screen
Navigator.push(context, MaterialPageRoute(
  builder: (context) => const AuthDebugWidget(),
));
```

### 2. Run Diagnostics
```dart
import 'package:flutter_onegate/utils/auth_debug_tool.dart';

// Run comprehensive diagnostics
final results = await AuthDebugTool.runDiagnostics();
AuthDebugTool.printDiagnosticsReport(results);
```

### 3. Enhanced Logging
```dart
// Enable detailed logging in enhanced_auth_service.dart
// All authentication steps are logged with 🔐 emojis
```

## 📋 Step-by-Step Debugging Process

### Step 1: Verify Configuration
```dart
// Run configuration validation
final validation = EnhancedKeycloakConfig.validateConfiguration();
print('Configuration valid: ${validation['isValid']}');
```

### Step 2: Test Network Connectivity
```dart
// Test endpoint connectivity
final connectivity = await EnhancedKeycloakConfig.testEndpointConnectivity();
connectivity.forEach((endpoint, reachable) {
  print('$endpoint: ${reachable ? 'OK' : 'FAILED'}');
});
```

### Step 3: Test Authentication Flow
```dart
// Use enhanced auth service
final authService = EnhancedAuthService(
  gateStorage: GetIt.I<GateStorage>(),
  remoteDataSource: GetIt.I<RemoteDataSource>(),
);

try {
  await authService.initialize();
  final result = await authService.login();
  print('Authentication: ${result != null ? 'SUCCESS' : 'FAILED'}');
} catch (e) {
  print('Authentication error: $e');
}
```

## 🔍 Keycloak Server-Side Checklist

### Client Configuration
```
□ Client exists: onegate-sso
□ Client enabled: true
□ Client protocol: openid-connect
□ Access type: public (recommended)
□ Standard flow enabled: true
□ Direct access grants enabled: true
□ Service accounts enabled: false (for public clients)
□ Authorization enabled: false (for public clients)
```

### Redirect URIs
```
□ Valid Redirect URIs: com.cubeonebiz.gate://login-callback
□ Valid Post Logout Redirect URIs: com.cubeonebiz.gate://logout-callback
□ Web Origins: * (or specific origins)
```

### Advanced Settings
```
□ Proof Key for Code Exchange Code Challenge Method: S256
□ Access Token Lifespan: 5 minutes (or as needed)
□ Client Session Idle: 30 minutes (or as needed)
□ Client Session Max: 10 hours (or as needed)
```

### Realm Settings
```
□ Realm enabled: true
□ User registration: as needed
□ Email verification: as needed
□ Login with email: as needed
□ Duplicate emails: false
```

## 🚀 Migration from keycloak_wrapper

### Key Differences

| Aspect | keycloak_wrapper | flutter_appauth |
|--------|------------------|-----------------|
| PKCE | Optional | Automatic |
| Client Type | Usually confidential | Public recommended |
| Token Storage | Built-in | Manual implementation |
| Error Handling | Basic | Comprehensive |
| Customization | Limited | Full control |

### Migration Steps

1. **Update Dependencies:**
   ```yaml
   dependencies:
     flutter_appauth: ^6.0.2
     # Remove keycloak_wrapper
   ```

2. **Update Configuration:**
   ```dart
   // Old: keycloak_wrapper config
   // New: EnhancedKeycloakConfig
   ```

3. **Update Authentication Flow:**
   ```dart
   // Old: KeycloakWrapper.login()
   // New: EnhancedAuthService.login()
   ```

4. **Test Thoroughly:**
   - Use AuthDebugWidget
   - Run diagnostics
   - Test all authentication flows

## 📞 Support

If issues persist after following this guide:

1. **Check Logs:** Enable debug logging and check console output
2. **Run Diagnostics:** Use the built-in diagnostic tools
3. **Verify Keycloak:** Double-check all Keycloak client settings
4. **Test Network:** Ensure all endpoints are reachable
5. **Review Configuration:** Validate all configuration parameters

## 🔗 Useful Resources

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [flutter_appauth Documentation](https://pub.dev/packages/flutter_appauth)
- [OAuth 2.0 / OIDC Specification](https://oauth.net/2/)
- [PKCE Specification](https://tools.ietf.org/html/rfc7636)
