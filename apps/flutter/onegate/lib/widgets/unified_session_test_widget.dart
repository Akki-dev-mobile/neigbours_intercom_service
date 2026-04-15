import 'package:flutter/material.dart';
import 'package:flutter_onegate/utils/session_debug_utility.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:flutter_onegate/services/session_manager/user_session_manager.dart';
import 'package:get_it/get_it.dart';
import 'dart:developer';

/// Test widget to verify unified session management is working correctly
class UnifiedSessionTestWidget extends StatefulWidget {
  const UnifiedSessionTestWidget({super.key});

  @override
  State<UnifiedSessionTestWidget> createState() => _UnifiedSessionTestWidgetState();
}

class _UnifiedSessionTestWidgetState extends State<UnifiedSessionTestWidget> {
  UserSessionState? _currentSessionState;
  bool _isListening = false;
  String _lastDebugResult = 'No debug run yet';

  @override
  void initState() {
    super.initState();
    _startListeningToSessionState();
  }

  void _startListeningToSessionState() {
    try {
      final sessionManager = GetIt.I<UserSessionManager>();
      
      setState(() {
        _currentSessionState = sessionManager.currentState;
        _isListening = true;
      });

      // Listen to session state changes
      sessionManager.sessionStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _currentSessionState = state;
          });
          log('🔄 Session state changed to: $state');
        }
      });
    } catch (e) {
      log('❌ Error starting session state listener: $e');
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _runDebugCheck() async {
    try {
      log('🔍 Running unified session debug check...');
      await SessionDebugUtility.debugSessionState();
      
      final shouldShow = await SessionDebugUtility.shouldShowSessionExpiredModal();
      
      setState(() {
        _lastDebugResult = context.tr(
          'Debug completed successfully.\nShould show session expired modal: {value}',
          params: {'value': '$shouldShow'},
        );
      });
    } catch (e) {
      setState(() {
        _lastDebugResult =
            context.tr('Debug failed: {error}', params: {'error': '$e'});
      });
    }
  }

  Future<void> _testTokenRefresh() async {
    try {
      log('🔄 Testing token refresh...');
      await SessionDebugUtility.testTokenRefresh();
      
      setState(() {
        _lastDebugResult =
            context.tr('Token refresh test completed successfully');
      });
    } catch (e) {
      setState(() {
        _lastDebugResult = context.tr(
          'Token refresh test failed: {error}',
          params: {'error': '$e'},
        );
      });
    }
  }

  Color _getStateColor(UserSessionState? state) {
    switch (state) {
      case UserSessionState.authenticated:
        return Colors.green;
      case UserSessionState.unauthenticated:
        return Colors.red;
      case UserSessionState.tokenExpired:
        return Colors.orange;
      case UserSessionState.error:
        return Colors.red.shade800;
      case UserSessionState.unknown:
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('Unified Session Management Test'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Session State Display
            Row(
              children: [
                Text(context.tr('Current State: ')),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStateColor(_currentSessionState),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _currentSessionState?.toString().split('.').last ??
                        context.tr('Unknown'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Listening Status
            Row(
              children: [
                Icon(
                  _isListening ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: _isListening ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr(
                    'Session State Listener: {status}',
                    params: {
                      'status':
                          _isListening ? context.tr('Active') : context.tr('Inactive'),
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _runDebugCheck,
                  icon: const Icon(Icons.bug_report, size: 16),
                  label: Text(context.tr('Debug Check')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _testTokenRefresh,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(context.tr('Test Refresh')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Debug Result Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Last Debug Result:'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lastDebugResult,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Expected Behavior Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('Expected Behavior:'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      '• Session state should be "authenticated" when logged in\n• Session expired modal should NOT appear\n• Tokens should refresh automatically in background\n• All unified session flags should be true',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
