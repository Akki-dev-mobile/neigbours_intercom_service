import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
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
  String _status = '';
  int _logCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeNetworkLogger();
  }

  Future<void> _initializeNetworkLogger() async {
    setState(() {
      _status = context.tr('Initializing...');
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
        _status = context.tr('Initialized');
      });
      
      if (kDebugMode) {
        dev.log('NetworkLogManager initialized and interceptor added to Dio');
      }
    } catch (e) {
      setState(() {
        _status = context.tr('Error: {error}', params: {'error': '$e'});
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
      _status = context.tr('Making GET request...');
    });
    
    try {
      final response = await _dio.get('https://jsonplaceholder.typicode.com/posts/1');
      
      setState(() {
        _status = context.tr(
          'GET request successful: {status}',
          params: {'status': '${response.statusCode}'},
        );
      });
      
      // Update log count
      _updateLogCount();
    } catch (e) {
      setState(() {
        _status = context.tr(
          'Error making GET request: {error}',
          params: {'error': '$e'},
        );
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
      _status = context.tr('Making POST request...');
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
        _status = context.tr(
          'POST request successful: {status}',
          params: {'status': '${response.statusCode}'},
        );
      });
      
      // Update log count
      _updateLogCount();
    } catch (e) {
      setState(() {
        _status = context.tr(
          'Error making POST request: {error}',
          params: {'error': '$e'},
        );
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
      _status = context.tr('Making failed request...');
    });
    
    try {
      await _dio.get('https://nonexistent-domain-12345.com');
    } catch (e) {
      setState(() {
        _status = context.tr(
          'Expected error making failed request: {error}',
          params: {'error': '${e.runtimeType}'},
        );
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
        title: Text(context.tr('Test Network Log Capture')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Status: {status}', params: {'status': _status}),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('Log Count: {count}', params: {'count': '$_logCount'}),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildButton(
              context.tr('Make GET Request'),
              _makeGetRequest,
            ),
            _buildButton(
              context.tr('Make POST Request'),
              _makePostRequest,
            ),
            _buildButton(
              context.tr('Make Failed Request'),
              _makeFailedRequest,
            ),
            _buildButton(
              context.tr('View Network Logs'),
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
