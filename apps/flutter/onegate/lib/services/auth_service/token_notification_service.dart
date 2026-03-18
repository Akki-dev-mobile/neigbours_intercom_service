import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/main.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Service for showing token-related notifications and status updates
class TokenNotificationService {
  static final TokenNotificationService _instance =
      TokenNotificationService._internal();
  factory TokenNotificationService() => _instance;
  TokenNotificationService._internal();

  // Track current notification state
  bool _isShowingRefreshNotification = false;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _currentSnackBar;

  // Configuration flag to control whether notifications are shown
  bool _showNotifications = false;

  /// Configure whether to show notifications
  /// Set to false to hide all token refresh snackbars
  void setShowNotifications(bool show) {
    _showNotifications = show;
    log("🔧 Token notifications ${show ? 'enabled' : 'disabled'}");
  }

  /// Get current notification configuration
  bool get showNotifications => _showNotifications;

  /// Show token information in a snackbar
  void showTokenInfo(String token, {String tokenType = "Access Token"}) {
    try {
      final userInfo = JwtTokenUtility.getUserInfoFromToken(token);
      final timeUntilExpiration = JwtTokenUtility.getTimeUntilExpiration(token);

      if (userInfo == null) {
        _showToast("❌ Invalid $tokenType", isError: true);
        return;
      }

      final userName =
          userInfo['name'] ?? userInfo['preferred_username'] ?? 'Unknown User';
      final expiresIn = timeUntilExpiration != null
          ? _formatDuration(timeUntilExpiration)
          : 'Unknown';

      final message = "🔑 $tokenType\n👤 $userName\n⏰ Expires in: $expiresIn";

      _showSnackBar(
        message,
        backgroundColor: Colors.blue.shade700,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Details',
          textColor: Colors.white,
          onPressed: () => _showDetailedTokenInfo(token, tokenType),
        ),
      );

      log("📋 Token info shown for $userName");
    } catch (e) {
      log("❌ Error showing token info: $e");
      _showToast("❌ Error displaying token info", isError: true);
    }
  }

  /// Show detailed token information in a dialog
  void _showDetailedTokenInfo(String token, String tokenType) {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) return;

      final userInfo = JwtTokenUtility.getUserInfoFromToken(token);
      if (userInfo == null) return;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.security, color: Colors.blue),
                const SizedBox(width: 8),
                Text('$tokenType Details'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoRow('👤 Name', userInfo['name'] ?? 'N/A'),
                  _buildInfoRow('📧 Email', userInfo['email'] ?? 'N/A'),
                  _buildInfoRow(
                      '🆔 Username', userInfo['preferred_username'] ?? 'N/A'),
                  _buildInfoRow('🏢 Client', userInfo['client_id'] ?? 'N/A'),
                  _buildInfoRow('🏛️ Issuer', userInfo['issuer'] ?? 'N/A'),
                  _buildInfoRow(
                      '⏰ Issued At', _formatDateTime(userInfo['issued_at'])),
                  _buildInfoRow(
                      '⏰ Expires At', _formatDateTime(userInfo['expires_at'])),
                  _buildInfoRow('🔐 Scopes',
                      (userInfo['scopes'] as List?)?.join(', ') ?? 'N/A'),
                  _buildInfoRow('🎭 Roles',
                      (userInfo['roles'] as List?)?.join(', ') ?? 'N/A'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      log("❌ Error showing detailed token info: $e");
    }
  }

  /// Show token refresh progress notification
  void showTokenRefreshProgress(
      {String message = "🔄 Refreshing token, please wait..."}) {
    if (_isShowingRefreshNotification) return;

    _isShowingRefreshNotification = true;

    // Only show snackbar if notifications are enabled
    if (_showNotifications) {
      _showSnackBar(
        message,
        backgroundColor: Colors.orange.shade700,
        duration:
            const Duration(seconds: 30), // Long duration for refresh process
        showProgress: true,
      );
    }

    log("🔄 Token refresh progress notification ${_showNotifications ? 'shown' : 'logged only'}");
  }

  /// Show token refresh success notification
  void showTokenRefreshSuccess({String? newToken}) {
    _dismissCurrentSnackBar();
    _isShowingRefreshNotification = false;

    // Only show notifications if enabled
    if (_showNotifications) {
      if (newToken != null) {
        final userInfo = JwtTokenUtility.getUserInfoFromToken(newToken);
        final userName =
            userInfo?['name'] ?? userInfo?['preferred_username'] ?? 'User';

        _showSnackBar(
          "✅ Token refreshed successfully!\n👤 Welcome back, $userName",
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () =>
                showTokenInfo(newToken, tokenType: "New Access Token"),
          ),
        );
      } else {
        _showToast("✅ Token refreshed successfully!", isError: false);
      }
    }

    log("✅ Token refresh success notification ${_showNotifications ? 'shown' : 'logged only'}");
  }

  /// Show token refresh failure notification
  void showTokenRefreshFailure({String? errorMessage}) {
    _dismissCurrentSnackBar();
    _isShowingRefreshNotification = false;

    final message = errorMessage != null
        ? "❌ Token refresh failed: $errorMessage"
        : "❌ Token refresh failed. Please login again.";

    // Only show snackbar if notifications are enabled
    if (_showNotifications) {
      _showSnackBar(
        message,
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Login',
          textColor: Colors.white,
          onPressed: () => _navigateToLogin(),
        ),
      );
    }

    log("❌ Token refresh failure notification ${_showNotifications ? 'shown' : 'logged only'}");
  }

  /// Show token expiration warning
  void showTokenExpirationWarning(Duration timeUntilExpiration) {
    final timeString = _formatDuration(timeUntilExpiration);

    _showSnackBar(
      "⚠️ Token expires in $timeString\nAutomatic refresh will occur soon",
      backgroundColor: Colors.amber.shade700,
      duration: const Duration(seconds: 4),
    );

    log("⚠️ Token expiration warning shown: $timeString remaining");
  }

  /// Show authentication error notification
  void showAuthenticationError({String? errorMessage}) {
    final message = errorMessage != null
        ? "🚫 Authentication error: $errorMessage"
        : "🚫 Authentication failed. Please login again.";

    // Only show snackbar if notifications are enabled
    if (_showNotifications) {
      _showSnackBar(
        message,
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Login',
          textColor: Colors.white,
          onPressed: () => _navigateToLogin(),
        ),
      );
    }

    log("🚫 Authentication error notification ${_showNotifications ? 'shown' : 'logged only'}");
  }

  /// Show network connectivity warning notification
  void showNetworkConnectivityWarning() {
    _showSnackBar(
      "🌐 Network connectivity lost\nSome features may be limited until connection is restored",
      backgroundColor: Colors.orange.shade700,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Retry',
        textColor: Colors.white,
        onPressed: () => _retryNetworkConnection(),
      ),
    );

    log("🌐 Network connectivity warning notification shown");
  }

  /// Retry network connection (placeholder for future implementation)
  void _retryNetworkConnection() {
    log("🔄 Network connection retry requested");
    _showToast("🔄 Checking network connection...");
  }

  /// Show a snackbar with custom styling
  void _showSnackBar(
    String message, {
    Color backgroundColor = Colors.blue,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    bool showProgress = false,
  }) {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) {
        log("⚠️ No context available for snackbar, falling back to toast");
        _showToast(message, backgroundColor: backgroundColor);
        return;
      }

      _dismissCurrentSnackBar();

      final snackBar = SnackBar(
        content: Row(
          children: [
            if (showProgress) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: DashboardLoaderIcon(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      );

      _currentSnackBar = ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } catch (e) {
      log("❌ Error showing snackbar: $e");
      _showToast(message, backgroundColor: backgroundColor);
    }
  }

  /// Show a toast notification as fallback
  void _showToast(String message,
      {Color? backgroundColor, bool isError = false}) {
    myFluttertoast(
      msg: message,
      backgroundColor: backgroundColor ?? (isError ? Colors.red : Colors.green),
      textColor: Colors.white,
      toastLength: Toast.LENGTH_LONG,
    );
  }

  /// Dismiss current snackbar if showing
  void _dismissCurrentSnackBar() {
    try {
      _currentSnackBar?.close();
      _currentSnackBar = null;
    } catch (e) {
      log("❌ Error dismissing snackbar: $e");
    }
  }

  /// Navigate to login screen
  void _navigateToLogin() {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      log("❌ Error navigating to login: $e");
    }
  }

  /// Build info row for dialog
  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return "${duration.inDays}d ${duration.inHours % 24}h";
    } else if (duration.inHours > 0) {
      return "${duration.inHours}h ${duration.inMinutes % 60}m";
    } else if (duration.inMinutes > 0) {
      return "${duration.inMinutes}m ${duration.inSeconds % 60}s";
    } else {
      return "${duration.inSeconds}s";
    }
  }

  /// Format DateTime for display
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  /// Clear all notifications
  void clearNotifications() {
    _dismissCurrentSnackBar();
    _isShowingRefreshNotification = false;
    log("🧹 All token notifications cleared");
  }
}
