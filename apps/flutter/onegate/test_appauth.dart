import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'lib/data/datasources/keycloack_config.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'AppAuth Test',
      home: AppAuthTestScreen(),
    );
  }
}

class AppAuthTestScreen extends StatefulWidget {
  const AppAuthTestScreen({super.key});

  @override
  _AppAuthTestScreenState createState() => _AppAuthTestScreenState();
}

class _AppAuthTestScreenState extends State<AppAuthTestScreen> {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  String _result = 'No test run yet';

  Future<void> _testAppAuth() async {
    try {
      setState(() {
        _result = 'Testing AppAuth configuration...';
      });

      // Display comprehensive configuration
      AppAuthConfigManager.logClientConfiguration(includeSecret: true);

      print('🔐 ===== STARTING APPAUTH TEST =====');

      // Test the authorization and token exchange
      final AuthorizationTokenResponse result =
          await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AppAuthConfigManager.clientId,
          AppAuthConfigManager.redirectUrl,
          serviceConfiguration: AppAuthConfigManager.getServiceConfiguration(),
          scopes: AppAuthConfigManager.scopes,
          additionalParameters: {
            'access_type': 'offline',
          },
        ),
      );

      if (result.accessToken != null) {
        setState(() {
          _result =
              '✅ SUCCESS!\nAccess Token: ${result.accessToken!.substring(0, 20)}...\nRefresh Token: ${result.refreshToken != null ? 'Present' : 'Not present'}';
        });
        print('✅ AppAuth test successful!');
      } else {
        setState(() {
          _result = '❌ FAILED: No access token received';
        });
      }
    } catch (e) {
      setState(() {
        _result = '❌ ERROR: $e';
      });
      print('❌ AppAuth test failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AppAuth Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _testAppAuth,
              child: const Text('Test AppAuth Login'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _result,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
