import 'dart:async';
import 'dart:developer';
import 'package:flutter/widgets.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple continuous session manager - keeps users logged in indefinitely
class SimpleContinuousSession with WidgetsBindingObserver {
  static final SimpleContinuousSession _instance = SimpleContinuousSession._internal();
  factory SimpleContinuousSession() => _instance;
  SimpleContinuousSession._internal();

  bool _isActive = false;
  Timer? _refreshTimer;

  /// Initialize and start continuous session
  Future<void> start() async {
    if (_isActive) return;

    try {
      log("🔐 Starting continuous session - user will stay logged in indefinitely");
      
      _isActive = true;
      
      // Disable timeouts
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('disable_idle_timeout', true);
      await prefs.setInt('session_timeout_ms', Duration(days: 365).inMilliseconds);
      
      // Start background refresh every 2 minutes
      _refreshTimer = Timer.periodic(Duration(minutes: 2), (timer) async {
        await _refreshToken();
      });
      
      // Save state
      await prefs.setBool('continuous_session_active', true);
      
      // Listen to app lifecycle
      WidgetsBinding.instance.addObserver(this);
      
      log("✅ Continuous session active - no re-authentication needed");
    } catch (e) {
      log("❌ Error starting continuous session: $e");
    }
  }

  /// Stop continuous session
  Future<void> stop() async {
    if (!_isActive) return;

    try {
      log("🚪 Stopping continuous session");
      
      _isActive = false;
      _refreshTimer?.cancel();
      
      // Re-enable timeouts
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('disable_idle_timeout');
      await prefs.remove('session_timeout_ms');
      await prefs.remove('continuous_session_active');
      
      WidgetsBinding.instance.removeObserver(this);
      
      log("✅ Continuous session stopped");
    } catch (e) {
      log("❌ Error stopping continuous session: $e");
    }
  }

  /// Background token refresh
  Future<void> _refreshToken() async {
    try {
      if (!_isActive) return;
      
      final authService = GetIt.I<AuthService>();
      final refreshed = await authService.tokenRefreshManager.refreshTokenIfNeeded();
      
      if (refreshed) {
        log("🔄 Background token refresh successful");
      } else {
        // Check if still authenticated
        final isAuth = await authService.isAuthenticated();
        if (!isAuth) {
          log("❌ Authentication lost - stopping continuous session");
          await stop();
        }
      }
    } catch (e) {
      log("❌ Background refresh error: $e");
    }
  }

  /// Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isActive && state == AppLifecycleState.resumed) {
      log("📱 App resumed - session maintained");
      _refreshToken();
    }
  }

  /// Check if active
  bool get isActive => _isActive;

  /// Restore session on app start
  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasActive = prefs.getBool('continuous_session_active') ?? false;
      
      if (wasActive) {
        final authService = GetIt.I<AuthService>();
        final isAuth = await authService.isAuthenticated();
        
        if (isAuth) {
          log("🔄 Restoring continuous session");
          await SimpleContinuousSession().start();
        } else {
          await prefs.remove('continuous_session_active');
        }
      }
    } catch (e) {
      log("❌ Error restoring session: $e");
    }
  }
}
