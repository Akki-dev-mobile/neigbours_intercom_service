import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/services/error_tracking/posthog_error_tracking_service.dart';
import 'dart:developer' as dev;

/// Simple test error button widget for PostHog Error Tracking verification
/// Only shows in debug mode
class TestErrorButton extends StatefulWidget {
  final String? screenName;
  final VoidCallback? onTestComplete;

  const TestErrorButton({
    Key? key,
    this.screenName,
    this.onTestComplete,
  }) : super(key: key);

  @override
  State<TestErrorButton> createState() => _TestErrorButtonState();
}

class _TestErrorButtonState extends State<TestErrorButton> {
  bool _isLoading = false;
  String _lastResult = '';

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _sendTestError,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bug_report, color: Colors.white),
            label: Text(
              _isLoading ? 'Sending...' : '🧪 Test PostHog Error',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          if (_lastResult.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _lastResult,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Send a test error to PostHog
  Future<void> _sendTestError() async {
    setState(() {
      _isLoading = true;
      _lastResult = '';
    });

    try {
      final screenName = widget.screenName ?? 'unknown_screen';
      final timestamp = DateTime.now();

      // Send test error to PostHog
      await PostHogErrorTrackingService.instance.captureError(
        error: Exception(
            '🧪 TEST ERROR: Manual PostHog verification from $screenName'),
        stackTrace: StackTrace.current,
        context: 'manual_test_button',
        errorType: 'ManualTestError',
        isFatal: false,
        additionalProperties: {
          'test_type': 'manual_button_test',
          'test_description': 'Manual test error triggered by test button',
          'screen_name': screenName,
          'timestamp': timestamp.toIso8601String(),
          'test_button_location': screenName,
          'manual_trigger': true,
        },
      );

      // Also send a user action error test
      await PostHogErrorTrackingService.instance.captureUserActionError(
        error: Exception(
            '🧪 TEST USER ACTION ERROR: Button test from $screenName'),
        action: 'test_error_button_click',
        screen: screenName,
        actionContext: {
          'button_type': 'test_error_button',
          'test_timestamp': timestamp.toIso8601String(),
        },
      );

      setState(() {
        _lastResult =
            '✅ Test errors sent successfully!\nCheck PostHog dashboard in 1-2 minutes.';
      });

      dev.log('🧪 Manual test errors sent to PostHog from $screenName');
      dev.log(
          '📊 Dashboard: https://us.posthog.com/project/170509/error_tracking');

      // Show success snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🧪 Test errors sent to PostHog!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View Dashboard',
              textColor: Colors.white,
              onPressed: () {
                dev.log(
                    '📊 Open: https://us.posthog.com/project/170509/error_tracking');
              },
            ),
          ),
        );
      }

      // Call completion callback
      widget.onTestComplete?.call();
    } catch (e) {
      setState(() {
        _lastResult = '❌ Test failed: $e';
      });

      dev.log('❌ Failed to send manual test error: $e');

      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

/// Quick test error function that can be called from anywhere
class PostHogTestHelper {
  /// Send a quick test error to PostHog
  static Future<void> sendQuickTestError({
    String? context,
    Map<String, dynamic>? additionalProperties,
  }) async {
    try {
      await PostHogErrorTrackingService.instance.captureError(
        error: Exception('🧪 QUICK TEST: PostHog Error Tracking verification'),
        stackTrace: StackTrace.current,
        context: context ?? 'quick_test',
        errorType: 'QuickTestError',
        isFatal: false,
        additionalProperties: {
          'test_type': 'quick_test',
          'test_description': 'Quick test error for PostHog verification',
          'timestamp': DateTime.now().toIso8601String(),
          ...?additionalProperties,
        },
      );

      dev.log('🧪 Quick test error sent to PostHog');
      dev.log('📊 Check: https://us.posthog.com/project/170509/error_tracking');
    } catch (e) {
      dev.log('❌ Quick test error failed: $e');
    }
  }

  /// Send multiple test errors of different types
  static Future<void> sendMultipleTestErrors({String? context}) async {
    final testContext = context ?? 'multiple_test';

    try {
      // Test 1: General error
      await PostHogErrorTrackingService.instance.captureError(
        error: Exception('🧪 TEST 1: General error'),
        context: testContext,
        errorType: 'GeneralTestError',
        isFatal: false,
      );

      // Test 2: Network error
      await PostHogErrorTrackingService.instance.captureNetworkError(
        error: Exception('🧪 TEST 2: Network error'),
        url: 'https://api.onegate.com/test',
        method: 'GET',
        statusCode: 500,
      );

      // Test 3: User action error
      await PostHogErrorTrackingService.instance.captureUserActionError(
        error: Exception('🧪 TEST 3: User action error'),
        action: 'test_action',
        screen: testContext,
      );

      dev.log('🧪 Multiple test errors sent to PostHog');
      dev.log('📊 Check: https://us.posthog.com/project/170509/error_tracking');
    } catch (e) {
      dev.log('❌ Multiple test errors failed: $e');
    }
  }
}
