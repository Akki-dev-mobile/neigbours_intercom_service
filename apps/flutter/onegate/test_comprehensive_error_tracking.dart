import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Comprehensive test script for PostHog Error Tracking
/// This script sends various types of errors to PostHog to verify the error tracking setup
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize PostHog
  await Posthog.init(
    apiKey: dotenv.env['POSTHOG_API_KEY'] ?? 'phc_g5SNI7g6Fv7WQBb8aLHnQGQKneECWNxRUup1pfxQ3mG',
    host: dotenv.env['POSTHOG_HOST'] ?? 'https://us.i.posthog.com',
  );
  
  print('🚀 PostHog initialized for comprehensive error tracking test');
  print('📊 Dashboard URL: https://us.posthog.com/project/170509/error_tracking');
  
  // Send comprehensive test errors
  await sendComprehensiveTestErrors();
  
  runApp(const ComprehensiveErrorTrackingTestApp());
}

/// Send comprehensive test errors to PostHog Error Tracking
Future<void> sendComprehensiveTestErrors() async {
  print('\n🧪 Starting comprehensive error tracking tests...\n');
  
  try {
    // Test 1: Flutter Framework Error
    await _sendFlutterFrameworkError();
    await _delay();
    
    // Test 2: Network Error
    await _sendNetworkError();
    await _delay();
    
    // Test 3: User Action Error
    await _sendUserActionError();
    await _delay();
    
    // Test 4: Platform Error
    await _sendPlatformError();
    await _delay();
    
    // Test 5: Fatal Error
    await _sendFatalError();
    await _delay();
    
    // Test 6: API Error
    await _sendAPIError();
    await _delay();
    
    // Test 7: Validation Error
    await _sendValidationError();
    await _delay();
    
    // Test 8: Authentication Error
    await _sendAuthenticationError();
    await _delay();
    
    print('✅ All comprehensive error tracking tests completed!');
    print('📊 Check PostHog Error Tracking dashboard: https://us.posthog.com/project/170509/error_tracking');
    print('🔍 Look for "\$exception" events with different error types');
    
  } catch (e) {
    print('❌ Error during comprehensive testing: $e');
  }
}

/// Test 1: Flutter Framework Error
Future<void> _sendFlutterFrameworkError() async {
  await Posthog().capture(
    eventName: '\$exception',
    properties: {
      '\$exception_type': 'FlutterError',
      '\$exception_message': 'Test Flutter framework error - Widget build failed',
      '\$exception_stack_trace': 'FlutterError: Widget build failed\n  at TestWidget.build(test_widget.dart:45)\n  at StatelessElement.build(element.dart:349)',
      '\$exception_fingerprint': 'flutter_widget_build_error',
      '\$exception_level': 'error',
      '\$exception_handled': true,
      'error_context': 'widget_build',
      'current_screen': 'dashboard',
      'timestamp': DateTime.now().toIso8601String(),
      'is_fatal': false,
      'user_id': 'test_user_001',
      'session_id': 'session_${DateTime.now().millisecondsSinceEpoch}',
      'gate_id': 'gate_001',
      'device_model': 'Test Device',
      'device_os': 'iOS',
      'device_os_version': '17.0',
      'app_version': '1.0.0',
      'test_type': 'flutter_framework_error',
    },
  );
  print('✅ Test 1: Flutter Framework Error sent');
}

/// Test 2: Network Error
Future<void> _sendNetworkError() async {
  await Posthog().capture(
    eventName: '\$exception',
    properties: {
      '\$exception_type': 'NetworkException',
      '\$exception_message': 'Network request failed - Connection timeout',
      '\$exception_stack_trace': 'NetworkException: Connection timeout\n  at ApiService.makeRequest(api_service.dart:123)\n  at VisitorService.getVisitors(visitor_service.dart:45)',
      '\$exception_fingerprint': 'network_timeout_error',
      '\$exception_level': 'error',
      '\$exception_handled': true,
      'error_context': 'network_request',
      'current_screen': 'visitor_list',
      'timestamp': DateTime.now().toIso8601String(),
      'is_fatal': false,
      'url': 'https://api.onegate.com/visitors',
      'method': 'GET',
      'status_code': 408,
      'user_id': 'test_user_002',
      'session_id': 'session_${DateTime.now().millisecondsSinceEpoch}',
      'gate_id': 'gate_002',
      'test_type': 'network_error',
    },
  );
  print('✅ Test 2: Network Error sent');
}

/// Test 3: User Action Error
Future<void> _sendUserActionError() async {
  await Posthog().capture(
    eventName: '\$exception',
    properties: {
      '\$exception_type': 'UserActionException',
      '\$exception_message': 'User action failed - Visitor approval failed',
      '\$exception_stack_trace': 'UserActionException: Visitor approval failed\n  at ApprovalService.approveVisitor(approval_service.dart:67)\n  at VisitorCard.onApprove(visitor_card.dart:89)',
      '\$exception_fingerprint': 'visitor_approval_error',
      '\$exception_level': 'error',
      '\$exception_handled': true,
      'error_context': 'user_interaction',
      'current_screen': 'visitor_approval',
      'timestamp': DateTime.now().toIso8601String(),
      'is_fatal': false,
      'action': 'approve_visitor',
      'visitor_id': 'visitor_123',
      'user_id': 'gatekeeper_001',
      'session_id': 'session_${DateTime.now().millisecondsSinceEpoch}',
      'gate_id': 'gate_003',
      'test_type': 'user_action_error',
    },
  );
  print('✅ Test 3: User Action Error sent');
}

/// Test 4: Platform Error
Future<void> _sendPlatformError() async {
  await Posthog().capture(
    eventName: '\$exception',
    properties: {
      '\$exception_type': 'PlatformException',
      '\$exception_message': 'Platform channel error - Camera permission denied',
      '\$exception_stack_trace': 'PlatformException: Camera permission denied\n  at CameraService.initializeCamera(camera_service.dart:34)\n  at QRScannerWidget.startScanning(qr_scanner.dart:56)',
      '\$exception_fingerprint': 'camera_permission_error',
      '\$exception_level': 'error',
      '\$exception_handled': true,
      'error_context': 'platform_channel',
      'current_screen': 'qr_scanner',
      'timestamp': DateTime.now().toIso8601String(),
      'is_fatal': false,
      'permission_type': 'camera',
      'user_id': 'test_user_003',
      'session_id': 'session_${DateTime.now().millisecondsSinceEpoch}',
      'gate_id': 'gate_004',
      'test_type': 'platform_error',
    },
  );
  print('✅ Test 4: Platform Error sent');
}

/// Test 5: Fatal Error
Future<void> _sendFatalError() async {
  await Posthog().capture(
    eventName: '\$exception',
    properties: {
      '\$exception_type': 'FatalException',
      '\$exception_message': 'Fatal application error - Unhandled null pointer exception',
      '\$exception_stack_trace': 'FatalException: Null pointer exception\n  at DataService.processData(data_service.dart:89)\n  at main.dart:45',
      '\$exception_fingerprint': 'fatal_null_pointer_error',
      '\$exception_level': 'fatal',
      '\$exception_handled': false,
      'error_context': 'application_crash',
      'current_screen': 'splash',
      'timestamp': DateTime.now().toIso8601String(),
      'is_fatal': true,
      'user_id': 'test_user_004',
      'session_id': 'session_${DateTime.now().millisecondsSinceEpoch}',
      'gate_id': 'gate_005',
      'test_type': 'fatal_error',
    },
  );
  print('✅ Test 5: Fatal Error sent');
}

/// Test 6: API Error
Future<void> _sendAPIError() async {
  await Posthog().capture(
    eventName: '\$exception',
    properties: {
      '\$exception_type': 'APIException',
      '\$exception_message': 'API error - Invalid authentication token',
      '\$exception_stack_trace': 'APIException: Invalid authentication token\n  at AuthService.validateToken(auth_service.dart:123)\n  at ApiInterceptor.onRequest(api_interceptor.dart:67)',
      '\$exception_fingerprint': 'api_auth_token_error',
      '\$exception_level': 'error',
      '\$exception_handled': true,
      'error_context': 'api_authentication',
      'current_screen': 'login',
      'timestamp': DateTime.now().toIso8601String(),
      'is_fatal': false,
      'api_endpoint': '/auth/validate',
      'status_code': 401,
      'user_id': 'test_user_005',
      'session_id': 'session_${DateTime.now().millisecondsSinceEpoch}',
      'gate_id': 'gate_006',
      'test_type': 'api_error',
    },
  );
  print('✅ Test 6: API Error sent');
}

/// Test 7: Validation Error
Future<void> _sendValidationError() async {
  await Posthog().capture(
    eventName: '\$exception',
    properties: {
      '\$exception_type': 'ValidationException',
      '\$exception_message': 'Validation error - Invalid visitor data format',
      '\$exception_stack_trace': 'ValidationException: Invalid visitor data\n  at VisitorValidator.validate(visitor_validator.dart:45)\n  at VisitorForm.onSubmit(visitor_form.dart:123)',
      '\$exception_fingerprint': 'visitor_validation_error',
      '\$exception_level': 'error',
      '\$exception_handled': true,
      'error_context': 'data_validation',
      'current_screen': 'visitor_registration',
      'timestamp': DateTime.now().toIso8601String(),
      'is_fatal': false,
      'validation_field': 'phone_number',
      'user_id': 'test_user_006',
      'session_id': 'session_${DateTime.now().millisecondsSinceEpoch}',
      'gate_id': 'gate_007',
      'test_type': 'validation_error',
    },
  );
  print('✅ Test 7: Validation Error sent');
}

/// Test 8: Authentication Error
Future<void> _sendAuthenticationError() async {
  await Posthog().capture(
    eventName: '\$exception',
    properties: {
      '\$exception_type': 'AuthenticationException',
      '\$exception_message': 'Authentication error - Session expired',
      '\$exception_stack_trace': 'AuthenticationException: Session expired\n  at SessionManager.validateSession(session_manager.dart:89)\n  at AuthGuard.canActivate(auth_guard.dart:34)',
      '\$exception_fingerprint': 'session_expired_error',
      '\$exception_level': 'error',
      '\$exception_handled': true,
      'error_context': 'session_management',
      'current_screen': 'dashboard',
      'timestamp': DateTime.now().toIso8601String(),
      'is_fatal': false,
      'session_duration': '3600',
      'user_id': 'test_user_007',
      'session_id': 'session_${DateTime.now().millisecondsSinceEpoch}',
      'gate_id': 'gate_008',
      'test_type': 'authentication_error',
    },
  );
  print('✅ Test 8: Authentication Error sent');
}

/// Add delay between tests
Future<void> _delay() async {
  await Future.delayed(const Duration(milliseconds: 500));
}

class ComprehensiveErrorTrackingTestApp extends StatelessWidget {
  const ComprehensiveErrorTrackingTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comprehensive Error Tracking Test',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Comprehensive Error Tracking Test'),
          backgroundColor: Colors.red.shade700,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              SizedBox(height: 20),
              Text(
                'Comprehensive Error Tests Sent!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                '8 different error types sent to PostHog',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Text(
                'Check PostHog Error Tracking Dashboard:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 5),
              Text(
                'https://us.posthog.com/project/170509/error_tracking',
                style: TextStyle(fontSize: 12, color: Colors.blue),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
