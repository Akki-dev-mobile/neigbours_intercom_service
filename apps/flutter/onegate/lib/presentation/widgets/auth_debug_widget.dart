import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/data/datasources/enhanced_keycloak_config.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_auth_service.dart';
import 'package:flutter_onegate/utils/auth_debug_tool.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:get_it/get_it.dart';

/// Debug widget for testing authentication configurations
class AuthDebugWidget extends StatefulWidget {
  const AuthDebugWidget({Key? key}) : super(key: key);

  @override
  State<AuthDebugWidget> createState() => _AuthDebugWidgetState();
}

class _AuthDebugWidgetState extends State<AuthDebugWidget> {
  late final EnhancedAuthService _authService;
  
  bool _isRunningDiagnostics = false;
  bool _isTestingAuth = false;
  Map<String, dynamic>? _diagnosticsResults;
  String? _authTestResult;
  String _logs = '';

  @override
  void initState() {
    super.initState();
    _authService = EnhancedAuthService(
      gateStorage: GetIt.I<GateStorage>(),
      remoteDataSource: GetIt.I<RemoteDataSource>(),
    );
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunningDiagnostics = true;
      _logs = '';
    });

    try {
      final results = await AuthDebugTool.runDiagnostics();
      AuthDebugTool.printDiagnosticsReport(results);
      
      setState(() {
        _diagnosticsResults = results;
      });
    } catch (e) {
      setState(() {
        _logs += 'Error running diagnostics: $e\n';
      });
    } finally {
      setState(() {
        _isRunningDiagnostics = false;
      });
    }
  }

  Future<void> _testAuthentication() async {
    setState(() {
      _isTestingAuth = true;
      _authTestResult = null;
      _logs = '';
    });

    try {
      await _authService.initialize();
      final result = await _authService.login();
      
      setState(() {
        _authTestResult = result != null ? 'SUCCESS' : 'FAILED';
        _logs += 'Authentication test completed: $_authTestResult\n';
        if (result != null) {
          _logs += 'User ID: ${result['sub']}\n';
          _logs += 'Username: ${result['preferred_username']}\n';
          _logs += 'Email: ${result['email']}\n';
        }
      });
    } catch (e) {
      setState(() {
        _authTestResult = 'ERROR';
        _logs += 'Authentication test failed: $e\n';
      });
    } finally {
      setState(() {
        _isTestingAuth = false;
      });
    }
  }

  void _showConfigurationDetails() {
    EnhancedKeycloakConfig.printConfigurationReport();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuration Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildConfigItem('Client ID', EnhancedKeycloakConfig.clientId),
              _buildConfigItem('Frontend URL', EnhancedKeycloakConfig.frontendUrl),
              _buildConfigItem('Realm', EnhancedKeycloakConfig.realm),
              _buildConfigItem('Bundle ID', EnhancedKeycloakConfig.bundleIdentifier),
              _buildConfigItem('Redirect URI', EnhancedKeycloakConfig.redirectUrl),
              _buildConfigItem('Client Type', 
                  EnhancedKeycloakConfig.isConfidentialClient ? 'CONFIDENTIAL' : 'PUBLIC'),
              _buildConfigItem('Scopes', EnhancedKeycloakConfig.scopes.join(', ')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsResults() {
    if (_diagnosticsResults == null) return const SizedBox.shrink();

    final summary = _diagnosticsResults!['summary'] as Map<String, dynamic>;
    final overallStatus = summary['overallStatus'] as String;
    final issues = summary['issues'] as List<String>;
    final warnings = summary['warnings'] as List<String>;

    Color statusColor;
    IconData statusIcon;
    switch (overallStatus) {
      case 'HEALTHY':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'WARNINGS':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case 'CRITICAL_ISSUES':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  'Status: $overallStatus',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (issues.isNotEmpty) ...[
              const Text(
                'Issues:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              ...issues.map((issue) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('• $issue', style: const TextStyle(color: Colors.red)),
                  )),
              const SizedBox(height: 8),
            ],
            if (warnings.isNotEmpty) ...[
              const Text(
                'Warnings:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              ...warnings.map((warning) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('• $warning', style: const TextStyle(color: Colors.orange)),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authentication Debug Tool'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Configuration Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configuration',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showConfigurationDetails,
                      icon: const Icon(Icons.settings),
                      label: const Text('View Configuration'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Diagnostics Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Diagnostics',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isRunningDiagnostics ? null : _runDiagnostics,
                      icon: _isRunningDiagnostics
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: DashboardLoaderIcon(strokeWidth: 2),
                            )
                          : const Icon(Icons.bug_report),
                      label: Text(_isRunningDiagnostics ? 'Running...' : 'Run Diagnostics'),
                    ),
                    const SizedBox(height: 16),
                    _buildDiagnosticsResults(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Authentication Test Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Authentication Test',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isTestingAuth ? null : _testAuthentication,
                      icon: _isTestingAuth
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: DashboardLoaderIcon(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(_isTestingAuth ? 'Testing...' : 'Test Authentication'),
                    ),
                    if (_authTestResult != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _authTestResult == 'SUCCESS' 
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          border: Border.all(
                            color: _authTestResult == 'SUCCESS' 
                                ? Colors.green 
                                : Colors.red,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _authTestResult == 'SUCCESS' 
                                  ? Icons.check_circle 
                                  : Icons.error,
                              color: _authTestResult == 'SUCCESS' 
                                  ? Colors.green 
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Authentication: $_authTestResult',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _authTestResult == 'SUCCESS' 
                                    ? Colors.green 
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Logs Section
            if (_logs.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Logs',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _logs,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
