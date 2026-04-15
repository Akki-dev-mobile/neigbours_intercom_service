import 'package:flutter/material.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:flutter_onegate/services/observatory/comprehensive_monitoring_service.dart';
import 'package:flutter_onegate/services/crash_reporting/crash_reporter_service.dart';
import 'package:flutter_onegate/services/crash_reporting/analytics_service.dart';
import 'package:flutter_onegate/services/error_tracking/posthog_error_tracking_service.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Debug widget for testing error tracking across all monitoring platforms
class ErrorTrackingTestWidget extends StatefulWidget {
  const ErrorTrackingTestWidget({Key? key}) : super(key: key);

  @override
  State<ErrorTrackingTestWidget> createState() =>
      _ErrorTrackingTestWidgetState();
}

class _ErrorTrackingTestWidgetState extends State<ErrorTrackingTestWidget> {
  String _lastTestResult = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Error Tracking Test')),
        backgroundColor: Colors.red.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Error Tracking Test Dashboard'),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('Test error tracking across all monitoring platforms:'),
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // Test Buttons
            ElevatedButton.icon(
              onPressed: _testPostHogError,
              icon: const Icon(Icons.analytics),
              label: Text(context.tr('Test PostHog Error')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: _testComprehensiveError,
              icon: const Icon(Icons.bug_report),
              label: Text(context.tr('Test All Platforms Error')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: _testCrashReporter,
              icon: const Icon(Icons.warning),
              label: Text(context.tr('Test Crash Reporter')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: _testPostHogErrorTracking,
              icon: const Icon(Icons.analytics_outlined),
              label: Text(context.tr('Test PostHog Error Tracking')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: _testAnalyticsError,
              icon: const Icon(Icons.track_changes),
              label: Text(context.tr('Test Analytics Error')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: _testFlutterError,
              icon: const Icon(Icons.error),
              label: Text(context.tr('Test Flutter Framework Error')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // Results
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Last Test Result:'),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lastTestResult.isEmpty
                        ? context.tr('No tests run yet')
                        : _lastTestResult,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Instructions:'),
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  SizedBox(height: 8),
                  Text(
                    context.tr(
                      '1. Tap any test button to generate errors\n2. Check PostHog dashboard for error events\n3. Look for "error_occurred" events in PostHog\n4. Verify error details in event properties',
                    ),
                    style: TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Test PostHog error tracking directly
  Future<void> _testPostHogError() async {
    try {
      await Posthog().capture(
        eventName: 'error_occurred',
        properties: {
          'error_type': 'TestException',
          'error_message': 'This is a test error for PostHog verification',
          'error_context': 'manual_test',
          'stack_trace': StackTrace.current.toString(),
          'is_fatal': false,
          'timestamp': DateTime.now().toIso8601String(),
          'test_type': 'direct_posthog_test',
          'platform': 'flutter',
          'app_version': '1.0.0',
        },
      );

      setState(() {
        _lastTestResult =
            'PostHog error sent successfully at ${DateTime.now()}';
      });
    } catch (e) {
      setState(() {
        _lastTestResult = 'PostHog error failed: $e';
      });
    }
  }

  /// Test comprehensive monitoring error
  Future<void> _testComprehensiveError() async {
    try {
      await ComprehensiveMonitoringService.instance.reportError(
        Exception('Test error from comprehensive monitoring'),
        stackTrace: StackTrace.current,
        context: 'comprehensive_test',
        properties: {
          'test_type': 'comprehensive_monitoring_test',
          'platform': 'flutter',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      setState(() {
        _lastTestResult =
            'Comprehensive error sent to all platforms at ${DateTime.now()}';
      });
    } catch (e) {
      setState(() {
        _lastTestResult = 'Comprehensive error failed: $e';
      });
    }
  }

  /// Test crash reporter
  Future<void> _testCrashReporter() async {
    try {
      await CrashReporterService().recordError(
        Exception('Test crash report error'),
        StackTrace.current,
        customKeys: {
          'test_type': 'crash_reporter_test',
          'timestamp': DateTime.now().toIso8601String(),
        },
        isFatal: false,
      );

      setState(() {
        _lastTestResult = 'Crash report sent at ${DateTime.now()}';
      });
    } catch (e) {
      setState(() {
        _lastTestResult = 'Crash report failed: $e';
      });
    }
  }

  /// Test analytics error tracking
  Future<void> _testAnalyticsError() async {
    try {
      await AnalyticsService().trackError(
        'TestError',
        'This is a test error for analytics verification',
        isFatal: false,
        additionalData: {
          'test_type': 'analytics_error_test',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      setState(() {
        _lastTestResult = 'Analytics error sent at ${DateTime.now()}';
      });
    } catch (e) {
      setState(() {
        _lastTestResult = 'Analytics error failed: $e';
      });
    }
  }

  /// Test Flutter framework error
  Future<void> _testFlutterError() async {
    try {
      // This will trigger the global error handler
      throw FlutterError(
          'Test Flutter framework error for monitoring verification');
    } catch (e) {
      // The error should be caught by the global handler
      setState(() {
        _lastTestResult =
            'Flutter error thrown at ${DateTime.now()} - should be caught by global handler';
      });
    }
  }

  /// Test PostHog Error Tracking specifically
  Future<void> _testPostHogErrorTracking() async {
    try {
      // Test different types of errors for PostHog
      await PostHogErrorTrackingService.instance.captureError(
        error: Exception('Test PostHog Error Tracking - General Error'),
        stackTrace: StackTrace.current,
        context: 'test_widget',
        errorType: 'TestError',
        isFatal: false,
        additionalProperties: {
          'test_type': 'posthog_error_tracking_test',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Test network error
      await PostHogErrorTrackingService.instance.captureNetworkError(
        error: Exception('Test network error for PostHog'),
        url: 'https://api.onegate.com/test',
        method: 'POST',
        statusCode: 500,
        requestData: {'test': 'data'},
        responseData: {'error': 'Internal server error'},
      );

      // Test user action error
      await PostHogErrorTrackingService.instance.captureUserActionError(
        error: Exception('Test user action error for PostHog'),
        action: 'test_button_click',
        screen: 'error_tracking_test',
        actionContext: {
          'button_id': 'test_posthog_button',
          'user_intent': 'testing_error_tracking',
        },
      );

      setState(() {
        _lastTestResult =
            'PostHog Error Tracking tests completed at ${DateTime.now()}';
      });
    } catch (e) {
      setState(() {
        _lastTestResult = 'PostHog Error Tracking test failed: $e';
      });
    }
  }
}
