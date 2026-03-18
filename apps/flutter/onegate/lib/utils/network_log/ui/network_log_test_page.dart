import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/utils/network_log/test_network_log.dart';
import 'package:flutter_onegate/utils/network_log/ui/network_log_screen.dart';
import 'package:flutter_onegate/utils/network_log/ui/network_log_sync_settings.dart';

class NetworkLogTestPage extends StatefulWidget {
  const NetworkLogTestPage({Key? key}) : super(key: key);

  @override
  State<NetworkLogTestPage> createState() => _NetworkLogTestPageState();
}

class _NetworkLogTestPageState extends State<NetworkLogTestPage> {
  final NetworkLogTester _tester = NetworkLogTester();
  bool _isRunningTests = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _initializeTester();
  }

  Future<void> _initializeTester() async {
    setState(() {
      _status = 'Initializing...';
    });

    await _tester.initialize();

    setState(() {
      _status = 'Ready';
    });
  }

  Future<void> _runAllTests() async {
    if (_isRunningTests) return;

    setState(() {
      _isRunningTests = true;
      _status = 'Running tests...';
    });

    try {
      await _tester.runAllTests();
      setState(() {
        _status = 'Tests completed';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isRunningTests = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Log Test'),
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
            const SizedBox(height: 24),
            const Text(
              'Test Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTestButton(
              'Make GET Request',
              _tester.makeTestGetRequest,
            ),
            _buildTestButton(
              'Make POST Request',
              _tester.makeTestPostRequest,
            ),
            _buildTestButton(
              'Make Failed Request',
              _tester.makeTestFailedRequest,
            ),
            _buildTestButton(
              'Trigger Manual Sync',
              _tester.triggerManualSync,
            ),
            _buildTestButton(
              'Run All Tests',
              _runAllTests,
              isLoading: _isRunningTests,
            ),
            const SizedBox(height: 24),
            const Text(
              'Navigation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildNavigationButton(
              'View Network Logs',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NetworkLogScreen(),
                ),
              ),
            ),
            _buildNavigationButton(
              'Sync Settings',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NetworkLogSyncSettings(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(String label, Function() onPressed, {bool isLoading = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: DashboardLoaderIcon(
                        strokeWidth: 2,
                      ),
                    )
                  : Text(label),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButton(String label, Function() onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: OutlinedButton(
        onPressed: onPressed,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Center(
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}
