/// Data models for authentication token debugging

/// Comprehensive token debug state
class TokenDebugState {
  final DateTime timestamp;
  final bool isAuthenticated;
  final bool isLoggedIn;
  final String? secureAccessToken;
  final String? secureRefreshToken;
  final String? gateAccessToken;
  final String? gateRefreshToken;
  final String? validAccessToken;
  final Duration? currentRefreshBuffer;
  final TokenAnalysis? accessTokenAnalysis;
  final TokenAnalysis? refreshTokenAnalysis;
  final StorageConsistency? storageConsistency;
  final Map<String, dynamic> refreshStats;
  final String? error;

  const TokenDebugState({
    required this.timestamp,
    required this.isAuthenticated,
    required this.isLoggedIn,
    this.secureAccessToken,
    this.secureRefreshToken,
    this.gateAccessToken,
    this.gateRefreshToken,
    this.validAccessToken,
    this.currentRefreshBuffer,
    this.accessTokenAnalysis,
    this.refreshTokenAnalysis,
    this.storageConsistency,
    this.refreshStats = const {},
    this.error,
  });

  /// Create initial empty state
  factory TokenDebugState.initial() {
    return TokenDebugState(
      timestamp: DateTime.now(),
      isAuthenticated: false,
      isLoggedIn: false,
    );
  }

  /// Create error state
  factory TokenDebugState.error(String error) {
    return TokenDebugState(
      timestamp: DateTime.now(),
      isAuthenticated: false,
      isLoggedIn: false,
      error: error,
    );
  }

  /// Check if state has any tokens
  bool get hasAnyTokens => 
      secureAccessToken != null || 
      secureRefreshToken != null || 
      gateAccessToken != null || 
      gateRefreshToken != null;

  /// Check if state has valid access token
  bool get hasValidAccessToken => 
      validAccessToken != null && 
      (accessTokenAnalysis?.isValid ?? false);

  /// Check if tokens need refresh
  bool get needsRefresh => 
      accessTokenAnalysis?.shouldRefreshNow ?? false;

  /// Get overall health status
  TokenHealthStatus get healthStatus {
    if (error != null) return TokenHealthStatus.error;
    if (!hasAnyTokens) return TokenHealthStatus.noTokens;
    if (!hasValidAccessToken) return TokenHealthStatus.invalid;
    if (needsRefresh) return TokenHealthStatus.needsRefresh;
    if (storageConsistency?.isConsistent ?? false) return TokenHealthStatus.healthy;
    return TokenHealthStatus.inconsistent;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenDebugState &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          isAuthenticated == other.isAuthenticated &&
          isLoggedIn == other.isLoggedIn &&
          secureAccessToken == other.secureAccessToken &&
          secureRefreshToken == other.secureRefreshToken &&
          gateAccessToken == other.gateAccessToken &&
          gateRefreshToken == other.gateRefreshToken &&
          validAccessToken == other.validAccessToken &&
          error == other.error;

  @override
  int get hashCode => Object.hash(
        timestamp,
        isAuthenticated,
        isLoggedIn,
        secureAccessToken,
        secureRefreshToken,
        gateAccessToken,
        gateRefreshToken,
        validAccessToken,
        error,
      );
}

/// Token analysis information
class TokenAnalysis {
  final String type;
  final bool isValid;
  final String? issuedAt;
  final String? expiresAt;
  final int? lifespanMinutes;
  final int? timeUntilExpiryMinutes;
  final bool? shouldRefreshNow;
  final int? refreshBuffer;
  final Map<String, dynamic>? userInfo;
  final Map<String, dynamic> rawAnalysis;
  final String? error;

  const TokenAnalysis({
    required this.type,
    required this.isValid,
    this.issuedAt,
    this.expiresAt,
    this.lifespanMinutes,
    this.timeUntilExpiryMinutes,
    this.shouldRefreshNow,
    this.refreshBuffer,
    this.userInfo,
    this.rawAnalysis = const {},
    this.error,
  });

  /// Create error analysis
  factory TokenAnalysis.error(String type, String error) {
    return TokenAnalysis(
      type: type,
      isValid: false,
      error: error,
    );
  }

  /// Check if token is expired
  bool get isExpired => timeUntilExpiryMinutes != null && timeUntilExpiryMinutes! <= 0;

  /// Check if token is expiring soon
  bool get isExpiringSoon => timeUntilExpiryMinutes != null && timeUntilExpiryMinutes! <= 5;

  /// Get user display name
  String? get userDisplayName => userInfo?['name'] ?? userInfo?['preferred_username'];

  /// Get user email
  String? get userEmail => userInfo?['email'];

  /// Get user roles
  List<String> get userRoles => List<String>.from(userInfo?['roles'] ?? []);
}

/// Storage consistency information
class StorageConsistency {
  final bool accessTokenMatch;
  final bool refreshTokenMatch;
  final bool secureStorageHasTokens;
  final bool gateStorageHasTokens;
  final bool bothStoragesPopulated;

  const StorageConsistency({
    required this.accessTokenMatch,
    required this.refreshTokenMatch,
    required this.secureStorageHasTokens,
    required this.gateStorageHasTokens,
    required this.bothStoragesPopulated,
  });

  /// Check if storage is consistent
  bool get isConsistent => 
      accessTokenMatch && 
      refreshTokenMatch && 
      bothStoragesPopulated;

  /// Get consistency issues
  List<String> get issues {
    final issues = <String>[];
    
    if (!accessTokenMatch) {
      issues.add('Access tokens do not match between storages');
    }
    
    if (!refreshTokenMatch) {
      issues.add('Refresh tokens do not match between storages');
    }
    
    if (!bothStoragesPopulated) {
      issues.add('Not all storage mechanisms have tokens');
    }
    
    return issues;
  }
}

/// Token health status enumeration
enum TokenHealthStatus {
  healthy,
  needsRefresh,
  invalid,
  inconsistent,
  noTokens,
  error,
}

/// Extension for user-friendly status descriptions
extension TokenHealthStatusExtension on TokenHealthStatus {
  String get description {
    switch (this) {
      case TokenHealthStatus.healthy:
        return 'All tokens are valid and consistent';
      case TokenHealthStatus.needsRefresh:
        return 'Tokens are valid but need refresh soon';
      case TokenHealthStatus.invalid:
        return 'Tokens are invalid or expired';
      case TokenHealthStatus.inconsistent:
        return 'Token storage is inconsistent';
      case TokenHealthStatus.noTokens:
        return 'No authentication tokens found';
      case TokenHealthStatus.error:
        return 'Error occurred while checking tokens';
    }
  }

  String get emoji {
    switch (this) {
      case TokenHealthStatus.healthy:
        return '✅';
      case TokenHealthStatus.needsRefresh:
        return '⚠️';
      case TokenHealthStatus.invalid:
        return '❌';
      case TokenHealthStatus.inconsistent:
        return '🔄';
      case TokenHealthStatus.noTokens:
        return '🚫';
      case TokenHealthStatus.error:
        return '💥';
    }
  }

  bool get isHealthy => this == TokenHealthStatus.healthy;
  bool get needsAttention => this != TokenHealthStatus.healthy;
}

/// Debug action results
class DebugActionResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  const DebugActionResult({
    required this.success,
    required this.message,
    this.data,
    required this.timestamp,
  });

  factory DebugActionResult.success(String message, {Map<String, dynamic>? data}) {
    return DebugActionResult(
      success: true,
      message: message,
      data: data,
      timestamp: DateTime.now(),
    );
  }

  factory DebugActionResult.failure(String message, {Map<String, dynamic>? data}) {
    return DebugActionResult(
      success: false,
      message: message,
      data: data,
      timestamp: DateTime.now(),
    );
  }
}

/// Token debug configuration
class TokenDebugConfig {
  final bool enableRealTimeUpdates;
  final Duration updateInterval;
  final bool enableDetailedLogging;
  final bool enableStorageConsistencyChecks;
  final bool enableTokenValidation;

  const TokenDebugConfig({
    this.enableRealTimeUpdates = true,
    this.updateInterval = const Duration(seconds: 10),
    this.enableDetailedLogging = true,
    this.enableStorageConsistencyChecks = true,
    this.enableTokenValidation = true,
  });

  /// Default configuration for development
  factory TokenDebugConfig.development() {
    return const TokenDebugConfig(
      enableRealTimeUpdates: true,
      updateInterval: Duration(seconds: 5),
      enableDetailedLogging: true,
      enableStorageConsistencyChecks: true,
      enableTokenValidation: true,
    );
  }

  /// Default configuration for production
  factory TokenDebugConfig.production() {
    return const TokenDebugConfig(
      enableRealTimeUpdates: false,
      updateInterval: Duration(minutes: 1),
      enableDetailedLogging: false,
      enableStorageConsistencyChecks: false,
      enableTokenValidation: false,
    );
  }
}
