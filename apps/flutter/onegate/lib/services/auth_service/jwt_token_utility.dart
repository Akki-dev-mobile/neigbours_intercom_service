import 'dart:convert';
import 'dart:developer';

/// Utility class for JWT token operations
class JwtTokenUtility {
  /// Parse JWT token and extract claims
  static Map<String, dynamic>? parseJwtToken(String token) {
    try {
      // JWT tokens have 3 parts separated by dots: header.payload.signature
      final parts = token.split('.');
      if (parts.length != 3) {
        log("❌ Invalid JWT format");
        return null;
      }

      // Decode the payload (second part)
      final payload = parts[1];
      // Add padding if needed for base64 decoding
      final normalizedPayload = base64Url.normalize(payload);
      final decodedBytes = base64Url.decode(normalizedPayload);
      final decodedPayload = utf8.decode(decodedBytes);
      final payloadJson = jsonDecode(decodedPayload) as Map<String, dynamic>;

      return payloadJson;
    } catch (e) {
      log("❌ Error parsing JWT token: $e");
      return null;
    }
  }

  /// Extract expiration time from JWT token
  static DateTime? getTokenExpirationTime(String token) {
    try {
      final payload = parseJwtToken(token);
      if (payload == null) return null;

      final exp = payload['exp'];
      if (exp == null) return null;

      // JWT exp claim is in seconds since epoch
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (e) {
      log("❌ Error extracting token expiration: $e");
      return null;
    }
  }

  /// Check if token is expired or will expire within the given buffer time
  static bool isTokenExpiredOrExpiring(String token,
      {Duration buffer = const Duration(minutes: 5)}) {
    try {
      final expirationTime = getTokenExpirationTime(token);
      if (expirationTime == null) {
        log("⚠️ Could not determine token expiration, considering it expired");
        return true;
      }

      final now = DateTime.now();
      final expirationWithBuffer = expirationTime.subtract(buffer);

      final isExpiring = now.isAfter(expirationWithBuffer);

      if (isExpiring) {
        log("🔄 Token will expire at $expirationTime (in ${expirationTime.difference(now).inMinutes} minutes)");
      }

      return isExpiring;
    } catch (e) {
      log("❌ Error checking token expiration: $e");
      return true; // Consider expired on error
    }
  }

  /// Extract user information from JWT token
  static Map<String, dynamic>? getUserInfoFromToken(String token) {
    try {
      final payload = parseJwtToken(token);
      if (payload == null) return null;

      return {
        'sub': payload['sub'],
        'email': payload['email'],
        'preferred_username': payload['preferred_username'],
        'name': payload['name'],
        'roles': payload['realm_access']?['roles'] ?? [],
        'client_id': payload['azp'] ?? payload['aud'],
        'issuer': payload['iss'],
        'issued_at': payload['iat'] != null
            ? DateTime.fromMillisecondsSinceEpoch(payload['iat'] * 1000)
            : null,
        'expires_at': payload['exp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(payload['exp'] * 1000)
            : null,
        'scopes': payload['scope']?.split(' ') ?? [],
      };
    } catch (e) {
      log("❌ Error extracting user info from token: $e");
      return null;
    }
  }

  /// Validate JWT token structure and basic claims
  static bool isValidJwtToken(String token) {
    try {
      final payload = parseJwtToken(token);
      if (payload == null) return false;

      // Check required claims
      final hasRequiredClaims = payload.containsKey('sub') &&
          payload.containsKey('exp') &&
          payload.containsKey('iat');

      if (!hasRequiredClaims) {
        log("❌ JWT token missing required claims");
        return false;
      }

      // Check if token is not expired
      final exp = payload['exp'];
      if (exp != null) {
        final expirationTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        if (DateTime.now().isAfter(expirationTime)) {
          log("❌ JWT token is expired");
          return false;
        }
      }

      return true;
    } catch (e) {
      log("❌ Error validating JWT token: $e");
      return false;
    }
  }

  /// Get time until token expiration
  static Duration? getTimeUntilExpiration(String token) {
    try {
      final expirationTime = getTokenExpirationTime(token);
      if (expirationTime == null) return null;

      final now = DateTime.now();
      if (now.isAfter(expirationTime)) {
        return Duration.zero; // Already expired
      }

      return expirationTime.difference(now);
    } catch (e) {
      log("❌ Error calculating time until expiration: $e");
      return null;
    }
  }

  /// Extract issued at time from JWT token
  static DateTime? getTokenIssuedAtTime(String token) {
    try {
      final payload = parseJwtToken(token);
      if (payload == null) return null;

      final iat = payload['iat'];
      if (iat == null) return null;

      // JWT iat claim is in seconds since epoch
      return DateTime.fromMillisecondsSinceEpoch(iat * 1000);
    } catch (e) {
      log("❌ Error extracting token issued at time: $e");
      return null;
    }
  }

  /// Calculate token lifespan in minutes
  static int? getTokenLifespanInMinutes(String token) {
    try {
      final issuedAt = getTokenIssuedAtTime(token);
      final expiresAt = getTokenExpirationTime(token);

      if (issuedAt == null || expiresAt == null) {
        log("⚠️ Could not determine token lifespan - missing iat or exp claims");
        return null;
      }

      final lifespan = expiresAt.difference(issuedAt);
      final lifespanMinutes = lifespan.inMinutes;

      log("📊 Token lifespan: $lifespanMinutes minutes (issued: $issuedAt, expires: $expiresAt)");
      return lifespanMinutes;
    } catch (e) {
      log("❌ Error calculating token lifespan: $e");
      return null;
    }
  }

  /// Calculate optimal refresh buffer based on token lifespan
  static Duration calculateOptimalRefreshBuffer(String token) {
    try {
      final lifespanMinutes = getTokenLifespanInMinutes(token);

      if (lifespanMinutes == null) {
        log("⚠️ Using default 1-minute buffer due to unknown token lifespan");
        return const Duration(minutes: 1);
      }

      Duration buffer;
      if (lifespanMinutes > 30) {
        buffer = const Duration(minutes: 5);
        log("📊 Token lifespan > 30 minutes ($lifespanMinutes min) → Using 5-minute refresh buffer");
      } else if (lifespanMinutes >= 15) {
        buffer = const Duration(minutes: 2);
        log("📊 Token lifespan 15-30 minutes ($lifespanMinutes min) → Using 2-minute refresh buffer");
      } else {
        buffer = const Duration(minutes: 1);
        log("📊 Token lifespan < 15 minutes ($lifespanMinutes min) → Using 1-minute refresh buffer");
      }

      // Ensure buffer is not larger than half the token lifespan
      final maxBuffer = Duration(minutes: (lifespanMinutes / 2).floor());
      if (buffer > maxBuffer) {
        buffer = maxBuffer;
        log("⚠️ Adjusted buffer to $buffer to not exceed half of token lifespan");
      }

      return buffer;
    } catch (e) {
      log("❌ Error calculating optimal refresh buffer: $e");
      return const Duration(minutes: 1);
    }
  }

  /// Get optimal refresh time (when refresh should occur)
  static DateTime? getOptimalRefreshTime(String token) {
    try {
      final expirationTime = getTokenExpirationTime(token);
      if (expirationTime == null) return null;

      final buffer = calculateOptimalRefreshBuffer(token);
      final refreshTime = expirationTime.subtract(buffer);

      log("⏰ Optimal refresh time: $refreshTime (${buffer.inMinutes} minutes before expiration)");
      return refreshTime;
    } catch (e) {
      log("❌ Error calculating optimal refresh time: $e");
      return null;
    }
  }

  /// Check if token should be refreshed now based on optimal timing
  static bool shouldRefreshTokenNow(String token) {
    try {
      final refreshTime = getOptimalRefreshTime(token);
      if (refreshTime == null) {
        log("⚠️ Cannot determine refresh time, recommending immediate refresh");
        return true;
      }

      final now = DateTime.now();
      final shouldRefresh = now.isAfter(refreshTime);

      if (shouldRefresh) {
        log("🔄 Token should be refreshed now (refresh time: $refreshTime, current: $now)");
      } else {
        final timeUntilRefresh = refreshTime.difference(now);
        log("⏳ Token refresh not needed yet (refresh in ${timeUntilRefresh.inMinutes} minutes)");
      }

      return shouldRefresh;
    } catch (e) {
      log("❌ Error checking if token should be refreshed: $e");
      return true;
    }
  }

  /// Get comprehensive token analysis for dynamic refresh system
  static Map<String, dynamic> getTokenAnalysis(String token) {
    try {
      final issuedAt = getTokenIssuedAtTime(token);
      final expiresAt = getTokenExpirationTime(token);
      final lifespanMinutes = getTokenLifespanInMinutes(token);
      final buffer = calculateOptimalRefreshBuffer(token);
      final refreshTime = getOptimalRefreshTime(token);
      final timeUntilExpiry = getTimeUntilExpiration(token);
      final shouldRefresh = shouldRefreshTokenNow(token);

      return {
        'issuedAt': issuedAt?.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'lifespanMinutes': lifespanMinutes,
        'refreshBuffer': buffer.inMinutes,
        'refreshTime': refreshTime?.toIso8601String(),
        'timeUntilExpiryMinutes': timeUntilExpiry?.inMinutes,
        'shouldRefreshNow': shouldRefresh,
        'isValid': isValidJwtToken(token),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      log("❌ Error getting token analysis: $e");
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Log detailed token information for debugging
  static void logTokenDetails(String tokenType, String token) {
    try {
      final userInfo = getUserInfoFromToken(token);
      if (userInfo == null) {
        log("❌ Could not extract user info from $tokenType");
        return;
      }

      log("📋 ===== $tokenType TOKEN DETAILS =====");
      log("👤 Subject: ${userInfo['sub']}");
      log("📧 Email: ${userInfo['email']}");
      log("👤 Username: ${userInfo['preferred_username']}");
      log("🏢 Name: ${userInfo['name']}");
      log("🔑 Client ID: ${userInfo['client_id']}");
      log("🏛️ Issuer: ${userInfo['issuer']}");
      log("⏰ Issued At: ${userInfo['issued_at']}");
      log("⏰ Expires At: ${userInfo['expires_at']}");
      log("🔐 Scopes: ${userInfo['scopes']}");
      log("🎭 Roles: ${userInfo['roles']}");

      final timeUntilExpiration = getTimeUntilExpiration(token);
      if (timeUntilExpiration != null) {
        log("⏱️ Time until expiration: ${timeUntilExpiration.inMinutes} minutes");
      }

      // Add dynamic refresh analysis
      final analysis = getTokenAnalysis(token);
      log("📊 Token Lifespan: ${analysis['lifespanMinutes']} minutes");
      log("🔄 Refresh Buffer: ${analysis['refreshBuffer']} minutes");
      log("⏰ Refresh Time: ${analysis['refreshTime']}");
      log("🎯 Should Refresh Now: ${analysis['shouldRefreshNow']}");

      log("📋 =====================================");
    } catch (e) {
      log("❌ Error logging token details: $e");
    }
  }
}
