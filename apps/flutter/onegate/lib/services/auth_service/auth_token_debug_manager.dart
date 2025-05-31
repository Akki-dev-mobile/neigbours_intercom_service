import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:get_it/get_it.dart';

/// Comprehensive authentication token debugging and state management system
class AuthTokenDebugManager extends ChangeNotifier {
  static final AuthTokenDebugManager _instance = AuthTokenDebugManager._internal();
  factory AuthTokenDebugManager() => _instance;
  AuthTokenDebugManager._internal();

  // Core components
  late final AuthService _authService;
  late final EnhancedTokenRefreshManager _tokenManager;
  late final GateStorage _gateStorage;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Debug state
  TokenDebugState _debugState = TokenDebugState.initial();
  Timer? _debugUpdateTimer;
  bool _isInitialized = false;
  bool _isDebuggingEnabled = false;

  // Stream controllers for real-time updates
  final StreamController<TokenDebugState> _debugStateController = 
      StreamController<TokenDebugState>.broadcast();

  /// Initialize the debug manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log("🔍 Initializing Auth Token Debug Manager");

      // Initialize dependencies
      _authService = GetIt.I<AuthService>();
      _tokenManager = _authService.tokenRefreshManager;
      _gateStorage = GetIt.I<GateStorage>();

      // Start debug monitoring
      await _startDebugMonitoring();

      _isInitialized = true;
      log("✅ Auth Token Debug Manager initialized");
    } catch (e) {
      log("❌ Error initializing Auth Token Debug Manager: $e");
      rethrow;
    }
  }

  /// Start continuous debug monitoring
  Future<void> _startDebugMonitoring() async {
    // Initial state update
    await _updateDebugState();

    // Start periodic updates every 10 seconds
    _debugUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_isDebuggingEnabled) {
        await _updateDebugState();
      }
    });

    log("🔄 Debug monitoring started");
  }

  /// Update debug state with current token information
  Future<void> _updateDebugState() async {
    try {
      final newState = await _collectTokenDebugInfo();
      
      if (_debugState != newState) {
        _debugState = newState;
        notifyListeners();
        _debugStateController.add(_debugState);
      }
    } catch (e) {
      log("❌ Error updating debug state: $e");
    }
  }

  /// Collect comprehensive token debug information
  Future<TokenDebugState> _collectTokenDebugInfo() async {
    try {
      // Get tokens from different sources
      final secureAccessToken = await _secureStorage.read(key: 'access_token');
      final secureRefreshToken = await _secureStorage.read(key: 'refresh_token');
      final gateAccessToken = await _gateStorage.getAccessToken();
      final gateRefreshToken = await _gateStorage.getRefreshToken();

      // Get authentication status
      final isAuthenticated = await _authService.isAuthenticated();
      final isLoggedIn = await _authService.isLoggedIn();

      // Get token manager status
      final validAccessToken = await _tokenManager.getValidAccessToken();
      final currentRefreshBuffer = _tokenManager.currentRefreshBuffer;

      // Analyze tokens
      TokenAnalysis? accessTokenAnalysis;
      TokenAnalysis? refreshTokenAnalysis;

      if (secureAccessToken != null) {
        accessTokenAnalysis = _analyzeToken(secureAccessToken, 'ACCESS');
      }

      if (secureRefreshToken != null) {
        refreshTokenAnalysis = _analyzeToken(secureRefreshToken, 'REFRESH');
      }

      // Get storage consistency
      final storageConsistency = _checkStorageConsistency(
        secureAccessToken,
        gateAccessToken,
        secureRefreshToken,
        gateRefreshToken,
      );

      // Get refresh manager statistics
      final refreshStats = _tokenManager.getRefreshFailureStatistics();

      return TokenDebugState(
        timestamp: DateTime.now(),
        isAuthenticated: isAuthenticated,
        isLoggedIn: isLoggedIn,
        secureAccessToken: secureAccessToken,
        secureRefreshToken: secureRefreshToken,
        gateAccessToken: gateAccessToken,
        gateRefreshToken: gateRefreshToken,
        validAccessToken: validAccessToken,
        currentRefreshBuffer: currentRefreshBuffer,
        accessTokenAnalysis: accessTokenAnalysis,
        refreshTokenAnalysis: refreshTokenAnalysis,
        storageConsistency: storageConsistency,
        refreshStats: refreshStats,
      );
    } catch (e) {
      log("❌ Error collecting token debug info: $e");
      return TokenDebugState.error(e.toString());
    }
  }

  /// Analyze a JWT token
  TokenAnalysis _analyzeToken(String token, String type) {
    try {
      final analysis = JwtTokenUtility.getTokenAnalysis(token);
      final userInfo = JwtTokenUtility.getUserInfoFromToken(token);
      final isValid = JwtTokenUtility.isValidJwtToken(token);
      final timeUntilExpiry = JwtTokenUtility.getTimeUntilExpiration(token);

      return TokenAnalysis(
        type: type,
        isValid: isValid,
        issuedAt: analysis['issuedAt'],
        expiresAt: analysis['expiresAt'],
        lifespanMinutes: analysis['lifespanMinutes'],
        timeUntilExpiryMinutes: analysis['timeUntilExpiryMinutes'],
        shouldRefreshNow: analysis['shouldRefreshNow'],
        refreshBuffer: analysis['refreshBuffer'],
        userInfo: userInfo,
        rawAnalysis: analysis,
      );
    } catch (e) {
      return TokenAnalysis.error(type, e.toString());
    }
  }

  /// Check consistency between different storage mechanisms
  StorageConsistency _checkStorageConsistency(
    String? secureAccess,
    String? gateAccess,
    String? secureRefresh,
    String? gateRefresh,
  ) {
    return StorageConsistency(
      accessTokenMatch: secureAccess == gateAccess,
      refreshTokenMatch: secureRefresh == gateRefresh,
      secureStorageHasTokens: secureAccess != null && secureRefresh != null,
      gateStorageHasTokens: gateAccess != null && gateRefresh != null,
      bothStoragesPopulated: (secureAccess != null && gateAccess != null) &&
                            (secureRefresh != null && gateRefresh != null),
    );
  }

  /// Enable debugging mode
  void enableDebugging() {
    _isDebuggingEnabled = true;
    log("🔍 Token debugging enabled");
    notifyListeners();
  }

  /// Disable debugging mode
  void disableDebugging() {
    _isDebuggingEnabled = false;
    log("🔍 Token debugging disabled");
    notifyListeners();
  }

  /// Force immediate token refresh for debugging
  Future<bool> forceTokenRefresh() async {
    try {
      log("🔄 Forcing token refresh for debugging");
      final result = await _tokenManager.refreshTokenIfNeeded();
      await _updateDebugState();
      return result;
    } catch (e) {
      log("❌ Error forcing token refresh: $e");
      return false;
    }
  }

  /// Clear all tokens for debugging
  Future<void> clearAllTokens() async {
    try {
      log("🧹 Clearing all tokens for debugging");
      await _secureStorage.deleteAll();
      await _gateStorage.clearTokens();
      await _updateDebugState();
      log("✅ All tokens cleared");
    } catch (e) {
      log("❌ Error clearing tokens: $e");
    }
  }

  /// Get current debug state
  TokenDebugState get currentState => _debugState;

  /// Get debug state stream
  Stream<TokenDebugState> get debugStateStream => _debugStateController.stream;

  /// Check if debugging is enabled
  bool get isDebuggingEnabled => _isDebuggingEnabled;

  /// Get formatted debug report
  String getFormattedDebugReport() {
    final state = _debugState;
    final buffer = StringBuffer();

    buffer.writeln("🔍 ===== AUTH TOKEN DEBUG REPORT =====");
    buffer.writeln("📅 Timestamp: ${state.timestamp}");
    buffer.writeln("🔐 Authenticated: ${state.isAuthenticated}");
    buffer.writeln("👤 Logged In: ${state.isLoggedIn}");
    buffer.writeln("");

    // Token presence
    buffer.writeln("📱 TOKEN PRESENCE:");
    buffer.writeln("  Secure Access Token: ${state.secureAccessToken != null ? '✅ Present' : '❌ Missing'}");
    buffer.writeln("  Secure Refresh Token: ${state.secureRefreshToken != null ? '✅ Present' : '❌ Missing'}");
    buffer.writeln("  Gate Access Token: ${state.gateAccessToken != null ? '✅ Present' : '❌ Missing'}");
    buffer.writeln("  Gate Refresh Token: ${state.gateRefreshToken != null ? '✅ Present' : '❌ Missing'}");
    buffer.writeln("  Valid Access Token: ${state.validAccessToken != null ? '✅ Present' : '❌ Missing'}");
    buffer.writeln("");

    // Access token analysis
    if (state.accessTokenAnalysis != null) {
      final analysis = state.accessTokenAnalysis!;
      buffer.writeln("🔑 ACCESS TOKEN ANALYSIS:");
      buffer.writeln("  Valid: ${analysis.isValid ? '✅' : '❌'}");
      buffer.writeln("  Expires At: ${analysis.expiresAt ?? 'Unknown'}");
      buffer.writeln("  Time Until Expiry: ${analysis.timeUntilExpiryMinutes ?? 'Unknown'} minutes");
      buffer.writeln("  Should Refresh Now: ${analysis.shouldRefreshNow ? '⚠️ Yes' : '✅ No'}");
      buffer.writeln("  Lifespan: ${analysis.lifespanMinutes ?? 'Unknown'} minutes");
      buffer.writeln("");
    }

    // Storage consistency
    if (state.storageConsistency != null) {
      final consistency = state.storageConsistency!;
      buffer.writeln("🔄 STORAGE CONSISTENCY:");
      buffer.writeln("  Access Token Match: ${consistency.accessTokenMatch ? '✅' : '❌'}");
      buffer.writeln("  Refresh Token Match: ${consistency.refreshTokenMatch ? '✅' : '❌'}");
      buffer.writeln("  Both Storages Populated: ${consistency.bothStoragesPopulated ? '✅' : '❌'}");
      buffer.writeln("");
    }

    // Refresh statistics
    if (state.refreshStats.isNotEmpty) {
      buffer.writeln("📊 REFRESH STATISTICS:");
      state.refreshStats.forEach((key, value) {
        buffer.writeln("  $key: $value");
      });
    }

    buffer.writeln("=====================================");
    return buffer.toString();
  }

  /// Dispose resources
  void dispose() {
    _debugUpdateTimer?.cancel();
    _debugStateController.close();
    super.dispose();
  }
}
