# Keycloak Token Refresh Requirements for OneGate Flutter App

## 📋 Executive Summary

The OneGate Flutter mobile application requires specific Keycloak token refresh behavior to implement **rolling refresh tokens** and **indefinite session management**. This document outlines the exact requirements, current issues, and expected server-side configuration.

## 🎯 Current Token Configuration

### **Access Tokens**
- **Lifetime**: 5 minutes
- **Format**: JWT with `iat` and `exp` claims
- **Refresh Strategy**: Every 3 minutes (2-minute buffer before expiry)

### **Refresh Tokens**
- **Lifetime**: 10 minutes
- **Expected Behavior**: Rolling refresh (new refresh token with each refresh)
- **Current Issue**: Refresh tokens may not be rolling properly

## 🔄 Expected Token Refresh Flow

### **Step 1: Initial Authentication**
```http
POST /auth/realms/{realm}/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&client_id={client_id}
&client_secret={client_secret}
&code={authorization_code}
&redirect_uri={redirect_uri}
```

**Expected Response:**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "id_token": "eyJhbGciOiJSUzI1NiIs...",
  "token_type": "Bearer",
  "expires_in": 300,
  "refresh_expires_in": 600,
  "scope": "openid profile email"
}
```

### **Step 2: Token Refresh (Every 3 Minutes)**
```http
POST /auth/realms/{realm}/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token
&client_id={client_id}
&client_secret={client_secret}
&refresh_token={current_refresh_token}
```

**Expected Response (CRITICAL):**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIs...",     // NEW access token
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",    // NEW refresh token (REQUIRED)
  "id_token": "eyJhbGciOiJSUzI1NiIs...",         // NEW id token
  "token_type": "Bearer",
  "expires_in": 300,                              // 5 minutes
  "refresh_expires_in": 600,                     // 10 minutes from NOW
  "scope": "openid profile email"
}
```

## ⚠️ Critical Requirements

### **1. Rolling Refresh Tokens (MANDATORY)**
- **MUST** return a **new refresh token** with each refresh request
- **MUST** extend refresh token expiry by 10 minutes from current time
- **MUST NOT** reuse the same refresh token

### **2. Token Expiry Behavior**
- Access token: 5 minutes from `iat` (issued at) time
- Refresh token: 10 minutes from refresh time (rolling window)
- Both tokens MUST include valid `iat` and `exp` JWT claims

### **3. Refresh Token Rotation**
```
Time 0:00 - Login: RT1 (expires 0:10)
Time 0:03 - Refresh: RT2 (expires 0:13) ← NEW refresh token
Time 0:06 - Refresh: RT3 (expires 0:16) ← NEW refresh token
Time 0:09 - Refresh: RT4 (expires 0:19) ← NEW refresh token
```

**Result**: User never experiences session expiry as long as app is active

## 🚨 Current Issues

### **Issue 1: Session Expired at 10 Minutes**
```
User reports: "Session expired modal appears at exactly 10 minutes"
```

**Root Cause**: Refresh tokens are NOT rolling - same refresh token reused
**Impact**: Session expires when initial refresh token expires

### **Issue 2: Refresh Token Not Updated**
```
Flutter App Behavior:
- Time 0:00: Login with RT1 (expires 0:10)
- Time 0:03: Refresh using RT1 → Server returns RT1 again (WRONG)
- Time 0:06: Refresh using RT1 → Server returns RT1 again (WRONG)
- Time 0:10: RT1 expires → Session expired modal
```

**Expected Behavior**:
```
Flutter App Behavior:
- Time 0:00: Login with RT1 (expires 0:10)
- Time 0:03: Refresh using RT1 → Server returns RT2 (expires 0:13) ✅
- Time 0:06: Refresh using RT2 → Server returns RT3 (expires 0:16) ✅
- Time 0:09: Refresh using RT3 → Server returns RT4 (expires 0:19) ✅
- Result: Infinite session ✅
```

## 🔧 Required Keycloak Configuration

### **Client Settings**
```
Client ID: onegate-mobile
Access Token Lifespan: 5 minutes
Refresh Token Lifespan: 10 minutes
Refresh Token Max Reuse: 0 (disable reuse)
Revoke Refresh Token: Enabled
```

### **Realm Settings**
```
Access Token Lifespan: 5 minutes
Access Token Lifespan For Implicit Flow: 5 minutes
Client Session Idle Timeout: 10 minutes
Client Session Max Lifespan: Unlimited (for rolling refresh)
```

### **Advanced Settings**
```
Refresh Token Max Reuse: 0
Revoke Refresh Token: ON
Use Refresh Tokens: ON
Use Refresh Tokens For Client Credentials Grant: OFF
```

## 📊 Token Refresh Verification

### **Test Case 1: Rolling Refresh Tokens**
```bash
# Initial login
curl -X POST "https://your-keycloak.com/auth/realms/onegate/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code&client_id=onegate-mobile&client_secret=xxx&code=xxx"

# Response should include:
# "refresh_token": "RT1_unique_value"
# "refresh_expires_in": 600

# First refresh (after 3 minutes)
curl -X POST "https://your-keycloak.com/auth/realms/onegate/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token&client_id=onegate-mobile&client_secret=xxx&refresh_token=RT1_unique_value"

# Response MUST include:
# "refresh_token": "RT2_different_value"  ← MUST be different from RT1
# "refresh_expires_in": 600               ← 10 minutes from NOW
```

### **Test Case 2: Refresh Token Expiry**
```bash
# Use old refresh token after getting new one
curl -X POST "https://your-keycloak.com/auth/realms/onegate/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token&client_id=onegate-mobile&client_secret=xxx&refresh_token=RT1_unique_value"

# Expected Response:
# HTTP 400 Bad Request
# {"error": "invalid_grant", "error_description": "Refresh token expired"}
```

## 🎯 Success Criteria

### **✅ Correct Behavior**
1. Each refresh returns a **NEW** refresh token
2. Old refresh tokens become **invalid** immediately
3. New refresh tokens have **10 minutes** from refresh time
4. Users can stay logged in **indefinitely** with active usage
5. Session expires only on **explicit logout** or **app inactivity > 10 minutes**

### **❌ Current Incorrect Behavior**
1. Same refresh token returned multiple times
2. Refresh token expiry not extended
3. Session expires at exactly 10 minutes regardless of activity

## 🔍 Debugging Information

### **Flutter App Logs**
```
🔄 Token refresh attempt 1/3
💾 Storing tokens with dynamic duration calculation...
📊 Access Token Duration Analysis:
   • Lifespan: 5 minutes
   • Refresh Buffer: 2 minutes
🔄 Refresh token is JWT - analyzing duration...
✅ Token refreshed successfully on attempt 1
```

### **Expected Server Logs**
```
[INFO] Token refresh request for client: onegate-mobile
[INFO] Refresh token RT1 validated successfully
[INFO] Issuing new refresh token RT2 (expires: 2024-01-01T10:13:00Z)
[INFO] Revoking old refresh token RT1
[INFO] Token refresh completed successfully
```

## 📞 Contact Information

**Flutter Development Team**: OneGate Mobile App
**Issue Priority**: High (affects user experience)
**Expected Resolution**: Rolling refresh token implementation

## 🛠️ Technical Implementation Details

### **Flutter App Token Management**
```dart
// Current implementation in OneGate app
await storeTokens(
  accessToken: tokenResponse.accessToken!,
  refreshToken: tokenResponse.refreshToken ??
      refreshToken, // Keeps old token if new one not provided
  idToken: tokenResponse.idToken,
);
```

**Problem**: If Keycloak doesn't provide new refresh token, app reuses old one

### **JWT Token Analysis**
```dart
// App analyzes JWT tokens for expiry
final expiryTime = JwtTokenUtility.getTokenExpirationTime(accessToken);
final issuedTime = JwtTokenUtility.getTokenIssuedAtTime(accessToken);
final actualDuration = expiryTime.difference(issuedTime);
```

**Requirement**: Both access and refresh tokens should be JWTs with valid `exp` claims

## 🔧 Keycloak Admin Console Configuration

### **Step 1: Client Configuration**
1. Navigate to: `Clients` → `onegate-mobile` → `Settings`
2. Set the following values:
   ```
   Access Token Lifespan: 5 minutes
   Client Session Idle Timeout: 10 minutes
   Client Session Max Lifespan: Leave empty (unlimited)
   ```

### **Step 2: Advanced Settings**
1. Navigate to: `Clients` → `onegate-mobile` → `Advanced Settings`
2. Configure:
   ```
   Refresh Token Max Reuse: 0
   Use Refresh Tokens: ON
   Revoke Refresh Token: ON
   ```

### **Step 3: Realm Settings**
1. Navigate to: `Realm Settings` → `Tokens`
2. Configure:
   ```
   Default Signature Algorithm: RS256
   Access Token Lifespan: 5 minutes
   Access Token Lifespan For Implicit Flow: 5 minutes
   Client Session Idle Timeout: 10 minutes
   Client Session Max Lifespan: Leave empty
   ```

## 🧪 Testing & Validation

### **Manual Testing Steps**
1. **Login and capture tokens**:
   ```bash
   # Save initial refresh token
   REFRESH_TOKEN_1="eyJhbGciOiJIUzI1NiIs..."
   ```

2. **Wait 3 minutes and refresh**:
   ```bash
   # This should return a NEW refresh token
   REFRESH_TOKEN_2="eyJhbGciOiJIUzI1NiIs..."  # Different from RT1
   ```

3. **Verify old token is invalid**:
   ```bash
   # Using RT1 should fail with invalid_grant
   curl -X POST "..." -d "refresh_token=$REFRESH_TOKEN_1"
   # Expected: {"error": "invalid_grant"}
   ```

### **Automated Testing Script**
```bash
#!/bin/bash
# Test rolling refresh tokens

KEYCLOAK_URL="https://your-keycloak.com"
REALM="onegate"
CLIENT_ID="onegate-mobile"
CLIENT_SECRET="your-secret"

# Function to refresh token
refresh_token() {
    local refresh_token=$1
    curl -s -X POST "$KEYCLOAK_URL/auth/realms/$REALM/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=refresh_token&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&refresh_token=$refresh_token"
}

# Test rolling refresh
echo "Testing rolling refresh tokens..."
RESULT1=$(refresh_token "$INITIAL_REFRESH_TOKEN")
NEW_REFRESH_TOKEN=$(echo "$RESULT1" | jq -r '.refresh_token')

if [ "$NEW_REFRESH_TOKEN" != "$INITIAL_REFRESH_TOKEN" ]; then
    echo "✅ Rolling refresh working - new token received"
else
    echo "❌ Rolling refresh NOT working - same token returned"
fi
```

## 🚨 Common Keycloak Misconfigurations

### **Issue 1: Refresh Token Reuse Enabled**
```
Problem: Refresh Token Max Reuse > 0
Solution: Set Refresh Token Max Reuse = 0
```

### **Issue 2: Revoke Refresh Token Disabled**
```
Problem: Revoke Refresh Token = OFF
Solution: Set Revoke Refresh Token = ON
```

### **Issue 3: Client Session Max Lifespan Too Short**
```
Problem: Client Session Max Lifespan = 10 minutes
Solution: Leave empty or set to very high value
```

### **Issue 4: Wrong Token Format**
```
Problem: Refresh tokens are opaque (not JWT)
Solution: Ensure JWT format for both access and refresh tokens
```

## 📈 Expected Metrics After Fix

### **Before Fix**
- Session duration: Exactly 10 minutes
- User complaints: "Logged out too frequently"
- Token refresh success rate: 100% until 10 minutes, then 0%

### **After Fix**
- Session duration: Unlimited (with activity)
- User complaints: Minimal
- Token refresh success rate: 100% continuously
- Background refresh frequency: Every 3 minutes

## 🔍 Monitoring & Logging

### **Keycloak Logs to Monitor**
```
[INFO] org.keycloak.events - type=REFRESH_TOKEN, realmId=onegate, clientId=onegate-mobile
[INFO] org.keycloak.events - type=REFRESH_TOKEN_ERROR, error=invalid_grant
```

### **Flutter App Logs to Share**
```
🔄 Token refresh attempt 1/3
💾 Storing tokens with dynamic duration calculation...
🔄 Refresh token is JWT - analyzing duration...
✅ Token refreshed successfully on attempt 1
```

## 📞 Next Steps

1. **Immediate**: Configure Keycloak settings as specified above
2. **Testing**: Run provided test scripts to verify rolling refresh
3. **Validation**: Monitor logs for successful token rotation
4. **Deployment**: Apply changes to production environment
5. **Monitoring**: Track session duration metrics post-deployment

---

**Please confirm the Keycloak configuration changes and provide test endpoints for verification.**

**Contact**: OneGate Development Team
**Priority**: High (User Experience Impact)
**Timeline**: Immediate resolution required
