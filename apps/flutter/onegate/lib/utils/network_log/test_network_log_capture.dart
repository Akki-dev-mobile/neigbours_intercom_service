import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/utils/network_log/network_log_manager.dart';
import 'package:flutter_onegate/utils/network_log/services/network_log_service.dart';
import 'package:flutter_onegate/utils/network_log/ui/network_log_screen.dart';

class TestNetworkLogCapture extends StatefulWidget {
  const TestNetworkLogCapture({Key? key}) : super(key: key);

  @override
  State<TestNetworkLogCapture> createState() => _TestNetworkLogCaptureState();
}

class _TestNetworkLogCaptureState extends State<TestNetworkLogCapture> {
  final NetworkLogManager _logManager = NetworkLogManager();
  final NetworkLogService _logService = NetworkLogService();
  final Dio _dio = Dio();
  bool _isLoading = false;
  String _status = 'Ready';
  int _logCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeNetworkLogger();
  }

  Future<void> _initializeNetworkLogger() async {
    setState(() {
      _status = 'Initializing...';
    });

    try {
      // Initialize the network log manager
      await _logManager.initialize();
      
      // Set the gate ID
      await _logManager.updateGateId('TEST_GATE');
      
      // Add the network logger interceptor to Dio
      _logManager.addInterceptorToDio(_dio);
      
      // Get the current log count
      _updateLogCount();
      
      setState(() {
        _status = 'Initialized';
      });
      
      if (kDebugMode) {
        dev.log('NetworkLogManager initialized and interceptor added to Dio');
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      if (kDebugMode) {
        dev.log('Error initializing NetworkLogManager: $e');
      }
    }
  }
  
  void _updateLogCount() {
    setState(() {
      _logCount = _logService.logs.value.length;
    });
  }

  Future<void> _makeGetRequest() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _status = 'Making GET request...';
    });
    
    try {
      final response = await _dio.get('https://jsonplaceholder.typicode.com/posts/1');
      
      setState(() {
        _status = 'GET request successful: ${response.statusCode}';
      });
      
      // Update log count
      _updateLogCount();
    } catch (e) {
      setState(() {
        _status = 'Error making GET request: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _makePostRequest() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _status = 'Making POST request...';
    });
    
    try {
      final response = await _dio.post(
        'https://jsonplaceholder.typicode.com/posts',
        data: {
          'title': 'Test Post',
          'body': 'This is a test post',
          'userId': 1,
        },
      );
      
      setState(() {
        _status = 'POST request successful: ${response.statusCode}';
      });
      
      // Update log count
      _updateLogCount();
    } catch (e) {
      setState(() {
        _status = 'Error making POST request: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _makeFailedRequest() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _status = 'Making failed request...';
    });
    
    try {
      await _dio.get('https://nonexistent-domain-12345.com');
    } catch (e) {
      setState(() {
        _status = 'Expected error making failed request: ${e.runtimeType}';
      });
      
      // Update log count
      _updateLogCount();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Network Log Capture'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: $_status',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log Count: $_logCount',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildButton(
              'Make GET Request',
              _makeGetRequest,
            ),
            _buildButton(
              'Make POST Request',
              _makePostRequest,
            ),
            _buildButton(
              'Make Failed Request',
              _makeFailedRequest,
            ),
            _buildButton(
              'View Network Logs',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NetworkLogScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
