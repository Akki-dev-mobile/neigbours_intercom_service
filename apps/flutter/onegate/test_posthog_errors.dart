import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Simple test script to verify PostHog error tracking
/// Run this with: flutter run test_posthog_errors.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize PostHog
  await Posthog.init(
    apiKey: dotenv.env['POSTHOG_API_KEY'] ?? 'phc_g5SNI7g6Fv7WQBb8aLHnQGQKneECWNxRUup1pfxQ3mG',
    host: dotenv.env['POSTHOG_HOST'] ?? 'https://us.i.posthog.com',
  );
  
  print('🚀 PostHog initialized, sending test errors...');
  
  // Send test errors
  await sendTestErrors();
  
  runApp(const PostHogErrorTestApp());
}

/// Send test errors to PostHog
Future<void> sendTestErrors() async {
  try {
    // Test Error 1: Simple error
    await Posthog().capture(
      eventName: 'error_occurred',
      properties: {
        'error_type': 'TestException',
        'error_message': 'Test error #1 - Simple error for PostHog verification',
        'error_context': 'test_script',
        'stack_trace': StackTrace.current.toString(),
        'is_fatal': false,
        'timestamp': DateTime.now().toIso8601String(),
        'test_type': 'simple_error_test',
        'platform': 'flutter',
        'app_version': '1.0.0',
      },
    );
    print('✅ Test error #1 sent to PostHog');
    
    await Future.delayed(const Duration(seconds: 1));
    
    // Test Error 2: Network error
    await Posthog().capture(
      eventName: 'error_occurred',
      properties: {
        'error_type': 'NetworkException',
        'error_message': 'Test error #2 - Network timeout error',
        'error_context': 'network_request',
        'stack_trace': StackTrace.current.toString(),
        'is_fatal': false,
        'timestamp': DateTime.now().toIso8601String(),
        'test_type': 'network_error_test',
        'platform': 'flutter',
        'url': 'https://api.example.com/test',
        'status_code': 408,
        'app_version': '1.0.0',
      },
    );
    print('✅ Test error #2 sent to PostHog');
    
    await Future.delayed(const Duration(seconds: 1));
    
    // Test Error 3: User action error
    await Posthog().capture(
      eventName: 'error_occurred',
      properties: {
        'error_type': 'UserActionException',
        'error_message': 'Test error #3 - User action failed',
        'error_context': 'user_interaction',
        'stack_trace': StackTrace.current.toString(),
        'is_fatal': false,
        'timestamp': DateTime.now().toIso8601String(),
        'test_type': 'user_action_error_test',
        'platform': 'flutter',
        'screen': 'dashboard',
        'action': 'button_click',
        'user_id': 'test_user_123',
        'app_version': '1.0.0',
      },
    );
    print('✅ Test error #3 sent to PostHog');
    
    await Future.delayed(const Duration(seconds: 1));
    
    // Test Error 4: Fatal error
    await Posthog().capture(
      eventName: 'error_occurred',
      properties: {
        'error_type': 'FatalException',
        'error_message': 'Test error #4 - Fatal application error',
        'error_context': 'application_crash',
        'stack_trace': StackTrace.current.toString(),
        'is_fatal': true,
        'timestamp': DateTime.now().toIso8601String(),
        'test_type': 'fatal_error_test',
        'platform': 'flutter',
        'app_version': '1.0.0',
        'device_info': 'Test Device',
      },
    );
    print('✅ Test error #4 sent to PostHog');
    
    print('🎉 All test errors sent successfully!');
    print('📊 Check your PostHog dashboard at: https://us.i.posthog.com');
    print('🔍 Look for "error_occurred" events in the Events section');
    
  } catch (e) {
    print('❌ Error sending test errors: $e');
  }
}

class PostHogErrorTestApp extends StatelessWidget {
  const PostHogErrorTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PostHog Error Test',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('PostHog Error Test'),
          backgroundColor: Colors.purple,
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
                'Test Errors Sent!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Check your PostHog dashboard for error events',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Text(
                'Dashboard: https://us.i.posthog.com',
                style: TextStyle(fontSize: 14, color: Colors.blue),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
