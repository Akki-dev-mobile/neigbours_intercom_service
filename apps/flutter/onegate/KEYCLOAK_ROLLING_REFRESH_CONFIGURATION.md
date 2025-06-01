# Keycloak Rolling Refresh Token Configuration

## 🎯 Problem Statement

**Issue:** Tokens have fixed expiry times instead of rolling expiry times, causing automatic logout.

**Evidence:**
```json
// Login at 4:25
{"exp": 1748775946, "iat": 1748775883}  // Expires at 4:32:26

// After refresh at 4:28  
{"exp": 1748775946, "iat": 1748775718}  // SAME expiry time ❌
```

**Root Cause:** Keycloak is using session-based expiry instead of token-based expiry.

## 🔧 Required Keycloak Configuration Changes

### **Step 1: Realm Session Settings (CRITICAL)**

**Navigate to:** `Realm Settings → Sessions`

| Setting | Current Value | Required Value | Why |
|---------|---------------|----------------|-----|
| SSO Session Idle Timeout | `10m` ❌ | `[BLANK]` ✅ | Prevents fixed session expiry |
| SSO Session Max Lifespan | `10h` ❌ | `[BLANK]` ✅ | Allows unlimited token refresh |
| SSO Session Idle Timeout Remember Me | `Any value` ❌ | `[BLANK]` ✅ | Prevents remember me limits |
| SSO Session Max Lifespan Remember Me | `Any value` ❌ | `[BLANK]` ✅ | Prevents remember me limits |

**⚠️ IMPORTANT:** These settings override token refresh behavior. They MUST be blank/empty.

### **Step 2: Realm Token Settings**

**Navigate to:** `Realm Settings → Tokens`

| Setting | Required Value | Description |
|---------|----------------|-------------|
| Access Token Lifespan | `5m` | Short-lived for security |
| Refresh Token Lifespan | `30m` | Long enough for rolling refresh |
| Access Token Lifespan For Implicit Flow | `5m` | Same as access token |
| Client Session Idle Timeout | `[BLANK]` | Don't override at realm level |
| Client Session Max Lifespan | `[BLANK]` | Don't override at realm level |
| Revoke Refresh Token | `OFF` ✅ | Allow token reuse |
| Refresh Token Max Reuse | `0` | Unlimited reuse |

### **Step 3: Client-Specific Settings**

**Navigate to:** `Clients → [OneGate Client] → Settings → Advanced Settings`

| Setting | Required Value | Why |
|---------|----------------|-----|
| Access Token Lifespan | `[BLANK]` | Inherit from realm |
| Client Session Idle Timeout | `[BLANK]` | No client-specific limits |
| Client Session Max Lifespan | `[BLANK]` | No client-specific limits |
| Use Refresh Tokens | `ON` ✅ | Enable refresh functionality |
| Use Refresh Tokens For Client Credentials Grant | `ON` ✅ | Enable for service accounts |

### **Step 4: Client Capability Configuration**

**Navigate to:** `Clients → [OneGate Client] → Settings → Capability config`

| Setting | Required Value | Purpose |
|---------|----------------|---------|
| Client authentication | `ON` ✅ | Secure client |
| Authorization | `OFF` | Not needed for mobile |
| Standard flow | `ON` ✅ | OAuth authorization code flow |
| Direct access grants | `ON` ✅ | Allow direct login |
| Implicit flow | `OFF` | Not secure for mobile |
| Service accounts roles | `OFF` | Not needed |

## 🔍 Configuration Verification

### **Before Fix (Current Issue):**
```bash
# Session Settings
SSO Session Idle Timeout: 10m ❌
SSO Session Max Lifespan: 10h ❌

# Result: All tokens expire at session idle time
Login at 4:25 → All tokens expire at 4:35 (10min later)
```

### **After Fix (Expected):**
```bash
# Session Settings  
SSO Session Idle Timeout: [BLANK] ✅
SSO Session Max Lifespan: [BLANK] ✅

# Result: Rolling token expiry
Login at 4:25 → Token expires at 4:30
Refresh at 4:28 → NEW token expires at 4:33
Refresh at 4:31 → NEW token expires at 4:36
```

## 🧪 Testing the Configuration

### **Step 1: Apply Configuration Changes**
1. Make all the above changes in Keycloak Admin Console
2. Click "Save" on each settings page
3. Restart Keycloak server (important!)

### **Step 2: Clear App Tokens**
```dart
// In Flutter app
final authService = EnhancedUnifiedAuthService();
await authService.logout(); // Clear old tokens
```

### **Step 3: Fresh Login and Monitor**
```dart
// Login again
await authService.login();

// Monitor token changes
Timer.periodic(Duration(minutes: 1), (_) async {
  final token = await authService.getValidAccessToken();
  if (token != null) {
    final payload = JwtTokenUtility.parseJwtToken(token);
    final exp = DateTime.fromMillisecondsSinceEpoch(payload['exp'] * 1000);
    print('Token expires at: ${exp.toString().substring(11, 19)}');
  }
});
```

### **Step 4: Expected Test Results**
```
16:25:00 - Login: Token expires at 16:30:00
16:28:00 - Refresh: Token expires at 16:33:00 ← NEW expiry time!
16:31:00 - Refresh: Token expires at 16:36:00 ← NEW expiry time!
16:34:00 - Refresh: Token expires at 16:39:00 ← NEW expiry time!
```

## 🚨 Common Configuration Mistakes

### **❌ Mistake 1: Setting Session Timeouts**
```
SSO Session Idle Timeout: 30m ❌
```
**Problem:** Even 30 minutes will cause fixed expiry.
**Solution:** Leave completely blank.

### **❌ Mistake 2: Client-Level Overrides**
```
Client → Advanced → Access Token Lifespan: 10m ❌
```
**Problem:** Overrides realm settings.
**Solution:** Leave blank to inherit from realm.

### **❌ Mistake 3: Enabling Token Revocation**
```
Revoke Refresh Token: ON ❌
```
**Problem:** Prevents token reuse for rolling refresh.
**Solution:** Set to OFF.

### **❌ Mistake 4: Limited Token Reuse**
```
Refresh Token Max Reuse: 1 ❌
```
**Problem:** Limits how many times refresh token can be used.
**Solution:** Set to 0 (unlimited).

## 📊 Configuration Summary

### **Critical Settings for Rolling Refresh:**

| Category | Setting | Value | Impact |
|----------|---------|-------|--------|
| **Sessions** | SSO Session Idle | `[BLANK]` | Prevents fixed expiry |
| **Sessions** | SSO Session Max | `[BLANK]` | Allows unlimited refresh |
| **Tokens** | Access Token Lifespan | `5m` | Security + refresh frequency |
| **Tokens** | Refresh Token Lifespan | `30m` | Rolling window duration |
| **Tokens** | Revoke Refresh Token | `OFF` | Enables token reuse |
| **Tokens** | Refresh Token Max Reuse | `0` | Unlimited refresh |

## 🎉 Expected Results After Fix

### **User Experience:**
- ✅ No automatic logout at 10 minutes
- ✅ No session expired modals during normal usage
- ✅ Seamless token refresh every 3-5 minutes
- ✅ True indefinite sessions

### **Token Behavior:**
- ✅ Each refresh gives NEW expiry time
- ✅ Rolling 5-minute windows
- ✅ Session continues as long as app is occasionally active
- ✅ Only logout after 30+ minutes of complete inactivity

### **Debug Logs:**
```
🔄 Starting token refresh...
✅ Token refresh successful
💾 Storing tokens securely...
⏰ Scheduling token refresh in 3 minutes (2min before expiry)
```

## 🔄 Restart Instructions

After making configuration changes:

### **Docker Keycloak:**
```bash
docker restart keycloak
```

### **Standalone Keycloak:**
```bash
./bin/kc.sh stop
./bin/kc.sh start
```

### **Kubernetes Keycloak:**
```bash
kubectl rollout restart deployment/keycloak
```

## 📞 Support

If issues persist after configuration:

1. **Verify all settings** are exactly as specified above
2. **Restart Keycloak** completely
3. **Clear app tokens** and login fresh
4. **Check Keycloak logs** for any errors during token refresh
5. **Test with Postman** to isolate backend vs frontend issues

The key insight: **Session settings override token settings**. For rolling refresh tokens, session limits must be disabled completely.
