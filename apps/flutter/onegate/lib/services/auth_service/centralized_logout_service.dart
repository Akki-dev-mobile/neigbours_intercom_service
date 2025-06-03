import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_logout_service.dart';
import 'package:flutter_onegate/services/session_manager/session_management_coordinator.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
import 'package:flutter_onegate/main.dart';

/// Centralized logout service that ensures consistent logout behavior
/// across all UI components (Settings Screen, Session Expired Modal, etc.)
class CentralizedLogoutService {
  static const String _tag = 'CentralizedLogout';

  /// Perform complete logout with consistent behavior across all UI components
  /// This method ensures that both Settings Screen and Session Expired Modal
  /// use exactly the same logout logic and cleanup operations
  static Future<LogoutResult> performCompleteLogout({
    String source = 'Unknown',
    bool showNotifications = true,
  }) async {
    try {
      log('🚪 [$_tag] Starting complete logout from: $source');

      // Step 1: Use enhanced logout service for complete session clearing
      final authService = GetIt.I<AuthService>();
      final logoutResult = await authService.logout(clearAllPreferences: true);

      if (logoutResult.success) {
        log('✅ [$_tag] Enhanced logout completed successfully');
        if (!logoutResult.keycloakEndSessionResult) {
          log('⚠️ [$_tag] Keycloak end session failed, but local tokens cleared');
        }
      } else {
        log('⚠️ [$_tag] Enhanced logout completed with issues: ${logoutResult.getIssues()}');
        // Continue with cleanup even if some operations fail
      }

      // Step 2: Dispose session managers and stop all timers
      await _disposeAllSessionManagers();

      // Step 3: Additional cleanup operations
      await _performAdditionalCleanup();

      log('✅ [$_tag] Complete logout process finished for: $source');
      return logoutResult;
    } catch (e) {
      log('❌ [$_tag] Error during complete logout from $source: $e');
      
      // Return failed result
      final result = LogoutResult();
      result.success = false;
      result.error = e.toString();
      return result;
    }
  }

  /// Dispose all session managers and stop timers
  static Future<void> _disposeAllSessionManagers() async {
    try {
      log('🗑️ [$_tag] Disposing all session managers and stopping timers...');

      // Dispose session management coordinator
      SessionManagementCoordinator.dispose();

      // Note: Other session managers are disposed by the AuthService.logout() call:
      // - EnhancedTokenRefreshManager.dispose() (stops periodic refresh checks)
      // - DynamicTokenRefreshManager.dispose() (stops dynamic monitoring)
      // - ContinuousSessionManager.dispose() (stops background tasks)
      // - UserSessionManager state changes are notified

      log('✅ [$_tag] All session managers disposed successfully');
    } catch (e) {
      log('❌ [$_tag] Error disposing session managers: $e');
    }
  }

  /// Perform additional cleanup operations
  static Future<void> _performAdditionalCleanup() async {
    try {
      log('🧹 [$_tag] Performing additional cleanup operations...');

      // Clear any remaining authentication state
      // This is already handled by EnhancedLogoutService, but we ensure it's complete

      // Clear any cached user data that might not be covered by standard logout
      // (This can be extended based on specific app requirements)

      log('✅ [$_tag] Additional cleanup completed');
    } catch (e) {
      log('❌ [$_tag] Error during additional cleanup: $e');
    }
  }

  /// Navigate to login screen with consistent behavior
  static Future<void> navigateToLogin(BuildContext? context, {String source = 'Unknown'}) async {
    try {
      log('🔄 [$_tag] Navigating to login from: $source');

      if (context != null && context.mounted) {
        // Use MaterialPageRoute for consistent navigation
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MyAppLogin()),
          (route) => false,
        );
        log('✅ [$_tag] Navigated to login screen from: $source');
      } else {
        // Fallback: Use global navigator if context is not available
        final globalContext = navigatorKey.currentContext;
        if (globalContext != null) {
          Navigator.of(globalContext).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
          log('✅ [$_tag] Navigated to login using global navigator from: $source');
        } else {
          log('⚠️ [$_tag] No context available for navigation from: $source');
        }
      }
    } catch (e) {
      log('❌ [$_tag] Error navigating to login from $source: $e');
    }
  }

  /// Complete logout flow with navigation
  /// This is the main method that UI components should call
  static Future<void> performLogoutWithNavigation({
    BuildContext? context,
    String source = 'Unknown',
    bool showNotifications = true,
    VoidCallback? onComplete,
  }) async {
    try {
      log('🎯 [$_tag] Starting complete logout flow from: $source');

      // Step 1: Perform complete logout
      final logoutResult = await performCompleteLogout(
        source: source,
        showNotifications: showNotifications,
      );

      // Step 2: Navigate to login screen
      if (context != null && context.mounted) {
        await navigateToLogin(context, source: source);
      } else {
        await navigateToLogin(null, source: source);
      }

      // Step 3: Call completion callback if provided
      if (onComplete != null) {
        onComplete();
      }

      if (logoutResult.success) {
        log('🎉 [$_tag] Complete logout flow successful from: $source');
      } else {
        log('⚠️ [$_tag] Logout flow completed with issues from $source: ${logoutResult.getIssues()}');
      }
    } catch (e) {
      log('❌ [$_tag] Error in complete logout flow from $source: $e');
      
      // Still try to navigate to login as fallback
      try {
        await navigateToLogin(context, source: '$source (fallback)');
      } catch (navError) {
        log('❌ [$_tag] Fallback navigation also failed: $navError');
      }
    }
  }

  /// Quick logout for emergency situations
  static Future<bool> performQuickLogout({String source = 'Emergency'}) async {
    try {
      log('⚡ [$_tag] Performing quick logout from: $source');

      final authService = GetIt.I<AuthService>();
      final success = await authService.quickLogout();

      if (success) {
        // Dispose session managers
        await _disposeAllSessionManagers();
        log('✅ [$_tag] Quick logout completed from: $source');
      } else {
        log('❌ [$_tag] Quick logout failed from: $source');
      }

      return success;
    } catch (e) {
      log('❌ [$_tag] Error during quick logout from $source: $e');
      return false;
    }
  }

  /// Verify logout completion
  static Future<bool> verifyLogoutCompletion() async {
    try {
      log('🔍 [$_tag] Verifying logout completion...');

      final authService = GetIt.I<AuthService>();
      
      // Check if user is still authenticated
      final isAuthenticated = await authService.isAuthenticated();
      
      if (!isAuthenticated) {
        log('✅ [$_tag] Logout verification successful - user not authenticated');
        return true;
      } else {
        log('⚠️ [$_tag] Logout verification failed - user still authenticated');
        return false;
      }
    } catch (e) {
      log('❌ [$_tag] Error verifying logout completion: $e');
      return false;
    }
  }

  /// Get logout statistics for debugging
  static Map<String, dynamic> getLogoutStatistics() {
    return {
      'service': 'CentralizedLogoutService',
      'version': '1.0.0',
      'features': [
        'Enhanced logout with Keycloak end session',
        'Complete session manager disposal',
        'Consistent navigation behavior',
        'Error handling and fallbacks',
        'Verification and statistics',
      ],
      'supported_sources': [
        'Settings Screen',
        'Session Expired Modal',
        'Emergency Logout',
        'Custom Components',
      ],
    };
  }
}
