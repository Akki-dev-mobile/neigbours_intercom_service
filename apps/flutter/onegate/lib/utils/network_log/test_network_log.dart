import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/utils/network_log/network_log_manager.dart';
import 'package:flutter_onegate/utils/network_log/services/network_log_sync_service.dart';

/// A utility class for testing the network logging functionality
class NetworkLogTester {
  final NetworkLogManager _logManager = NetworkLogManager();
  final Dio _dio = Dio();
  
  /// Initialize the network log tester
  Future<void> initialize() async {
    // Initialize the network log manager
    await _logManager.initialize();
    
    // Add the network logger interceptor to Dio
    _logManager.addInterceptorToDio(_dio);
    
    // Set the gate ID
    await _logManager.updateGateId('TEST_GATE');
    
    debugPrint('NetworkLogTester initialized');
  }
  
  /// Make a test GET request
  Future<void> makeTestGetRequest() async {
    try {
      debugPrint('Making test GET request...');
      final response = await _dio.get('https://jsonplaceholder.typicode.com/posts/1');
      debugPrint('GET request successful: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error making GET request: $e');
    }
  }
  
  /// Make a test POST request
  Future<void> makeTestPostRequest() async {
    try {
      debugPrint('Making test POST request...');
      final response = await _dio.post(
        'https://jsonplaceholder.typicode.com/posts',
        data: {
          'title': 'Test Post',
          'body': 'This is a test post',
          'userId': 1,
        },
      );
      debugPrint('POST request successful: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error making POST request: $e');
    }
  }
  
  /// Make a test request that will fail
  Future<void> makeTestFailedRequest() async {
    try {
      debugPrint('Making test failed request...');
      await _dio.get('https://nonexistent-domain-12345.com');
    } catch (e) {
      debugPrint('Expected error making failed request: ${e.runtimeType}');
    }
  }
  
  /// Trigger a manual sync
  Future<bool> triggerManualSync() async {
    debugPrint('Triggering manual sync...');
    final success = await _logManager.triggerManualSync();
    debugPrint('Manual sync ${success ? 'successful' : 'failed'}');
    return success;
  }
  
  /// Run all tests
  Future<void> runAllTests() async {
    await initialize();
    
    // Make test requests
    await makeTestGetRequest();
    await makeTestPostRequest();
    await makeTestFailedRequest();
    
    // Wait a bit for logs to be processed
    await Future.delayed(const Duration(seconds: 1));
    
    // Trigger manual sync
    await triggerManualSync();
  }
}
