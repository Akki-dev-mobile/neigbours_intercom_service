import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'dart:developer';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/auth_service/token_notification_service.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';

/// Debug widget for token management and display (only shown in debug mode)
class DebugTokenWidget extends StatefulWidget {
  const DebugTokenWidget({super.key});

  @override
  State<DebugTokenWidget> createState() => _DebugTokenWidgetState();
}

class _DebugTokenWidgetState extends State<DebugTokenWidget> {
  final TokenNotificationService _notificationService =
      TokenNotificationService();
  late final EnhancedTokenRefreshManager _tokenManager;
  late final AuthService _authService;

  bool _isInitialized = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      _authService = GetIt.I<AuthService>();
      _tokenManager = _authService.tokenRefreshManager;
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _lastError = e.toString();
      });
      log("❌ Error initializing debug token widget: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    if (!_isInitialized) {
      return _buildErrorWidget();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.security, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('Debug Token Manager'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),

              // Token Information Section
              _buildSectionTitle(context.tr('Token Information')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showCurrentTokenInfo,
                      icon: const Icon(Icons.info_outline),
                      label: Text(context.tr('Show Token Info')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _checkTokenValidity,
                      icon: const Icon(Icons.verified_user),
                      label: Text(context.tr('Check Validity')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Token Refresh Section
              _buildSectionTitle(context.tr('Token Refresh')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _manualTokenRefresh,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.tr('Manual Refresh')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _testTokenExpiration,
                      icon: const Icon(Icons.warning),
                      label: Text(context.tr('Test Expiration')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Notification Testing Section
              _buildSectionTitle(context.tr('Notification Testing')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _testRefreshNotification,
                      icon: const Icon(Icons.notifications),
                      label: Text(context.tr('Test Refresh')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _testErrorNotification,
                      icon: const Icon(Icons.error),
                      label: Text(context.tr('Test Error')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Clear Section
              _buildSectionTitle(context.tr('Token Management')),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _clearAllTokens,
                  icon: const Icon(Icons.clear_all),
                  label: Text(context.tr('Clear All Tokens')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              if (_lastError != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    context.tr('Last Error: {error}', params: {'error': '$_lastError'}),
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                context.tr('Debug Token Widget Error'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _lastError ?? context.tr('Failed to initialize token services'),
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.tr('Close')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
      ),
    );
  }

  // Action Methods
  Future<void> _showCurrentTokenInfo() async {
    try {
      await _tokenManager.showCurrentTokenInfo();
    } catch (e) {
      _setError(e.toString());
      _notificationService.showAuthenticationError(
          errorMessage:
              context.tr('Error showing token info: {error}', params: {'error': '$e'}));
    }
  }

  Future<void> _checkTokenValidity() async {
    try {
      final token = await _tokenManager.getValidAccessToken();
      if (token != null) {
        _notificationService.showTokenInfo(token,
            tokenType: context.tr('Valid Access Token'));
      } else {
        _notificationService.showAuthenticationError(
            errorMessage: context.tr('No valid access token available'));
      }
    } catch (e) {
      _setError(e.toString());
      _notificationService.showAuthenticationError(
          errorMessage:
              context.tr('Error checking token validity: {error}', params: {'error': '$e'}));
    }
  }

  Future<void> _manualTokenRefresh() async {
    try {
      final success = await _tokenManager.refreshTokenIfNeeded();
      if (!success) {
        _notificationService.showTokenRefreshFailure(
            errorMessage: context.tr('Manual refresh failed'));
      }
    } catch (e) {
      _setError(e.toString());
      _notificationService.showTokenRefreshFailure(
          errorMessage:
              context.tr('Manual refresh error: {error}', params: {'error': '$e'}));
    }
  }

  void _testTokenExpiration() {
    _notificationService.showTokenExpirationWarning(const Duration(minutes: 5));
  }

  void _testRefreshNotification() {
    _notificationService.showTokenRefreshProgress(
        message: context.tr('Testing refresh notification...'));

    // Simulate refresh completion after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      _notificationService.showTokenRefreshSuccess();
    });
  }

  void _testErrorNotification() {
    _notificationService.showAuthenticationError(
        errorMessage: context.tr('This is a test authentication error'));
  }

  Future<void> _clearAllTokens() async {
    try {
      await _tokenManager.clearTokens();
      _notificationService.showAuthenticationError(
          errorMessage: context.tr('All tokens cleared. Please login again.'));
    } catch (e) {
      _setError(e.toString());
      _notificationService.showAuthenticationError(
          errorMessage:
              context.tr('Error clearing tokens: {error}', params: {'error': '$e'}));
    }
  }

  void _setError(String error) {
    setState(() {
      _lastError = error;
    });
    log("❌ Debug Token Widget Error: $error");
  }
}

/// Show debug token widget as a modal bottom sheet
void showDebugTokenWidget(BuildContext context) {
  if (!kDebugMode) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const DebugTokenWidget(),
  );
}
