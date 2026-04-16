import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:flutter_onegate/services/auth_service/indefinite_session_manager.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';

final FlutterI18nDelegate _indefiniteSessionExampleI18nDelegate =
    FlutterI18nDelegate(
  translationLoader: FileTranslationLoader(
    basePath: 'assets/flutter_i18n',
    fallbackFile: 'en',
    useCountryCode: false,
  ),
);

/// Complete example app demonstrating indefinite session management
/// This shows how to implement "login once, stay logged in forever" functionality
class IndefiniteSessionExampleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (ctx) => ctx.tr('oneGateIndefiniteSessionsAppTitle'),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      localizationsDelegates: [
        AppLocalizations.delegate,
        _indefiniteSessionExampleI18nDelegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('mr'),
      ],
      home: AuthWrapper(),
    );
  }
}

/// Wrapper that handles authentication state
class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final EnhancedUnifiedAuthService _authService = EnhancedUnifiedAuthService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      await _authService.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('❌ Failed to initialize auth: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DashboardLoaderIcon(),
              SizedBox(height: 16),
              Text(context.tr('Initializing secure authentication...')),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<bool>(
      stream: _authService.authStateStream,
      builder: (context, snapshot) {
        final isAuthenticated = snapshot.data ?? false;
        
        if (isAuthenticated) {
          return HomeScreen(authService: _authService);
        } else {
          return LoginScreen(authService: _authService);
        }
      },
    );
  }

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }
}

/// Login screen with indefinite session support
class LoginScreen extends StatefulWidget {
  final EnhancedUnifiedAuthService authService;

  const LoginScreen({Key? key, required this.authService}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoggingIn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('OneGate Login')),
        backgroundColor: Colors.blue[700],
      ),
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.security,
              size: 80,
              color: Colors.blue[700],
            ),
            SizedBox(height: 32),
            Text(
              context.tr('Secure Authentication'),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              context.tr(
                'Login once and stay authenticated indefinitely with automatic token refresh.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 48),
            ElevatedButton(
              onPressed: _isLoggingIn ? null : _performLogin,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue[700],
              ),
              child: _isLoggingIn
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: DashboardLoaderIcon(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(context.tr('Logging in...')),
                      ],
                    )
                  : Text(
                      context.tr('Login with Keycloak'),
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            SizedBox(height: 24),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Features:'),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    _buildFeatureItem(
                      context.tr('Automatic token refresh every 2-3 minutes'),
                    ),
                    _buildFeatureItem(
                      context.tr('Secure token storage with encryption'),
                    ),
                    _buildFeatureItem(
                      context.tr('No session timeouts or expiry modals'),
                    ),
                    _buildFeatureItem(
                      context.tr('Persistent sessions across app restarts'),
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

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Text(text, style: TextStyle(fontSize: 14)),
    );
  }

  Future<void> _performLogin() async {
    setState(() {
      _isLoggingIn = true;
    });

    try {
      final userInfo = await widget.authService.login();
      if (userInfo != null) {
        print('✅ Login successful: ${userInfo['name']}');
        // Navigation handled automatically by StreamBuilder
      }
    } catch (e) {
      print('❌ Login failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Login failed: {error}', params: {'error': e.toString()}),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoggingIn = false;
      });
    }
  }
}

/// Home screen showing indefinite session features
class HomeScreen extends StatefulWidget {
  final EnhancedUnifiedAuthService authService;

  const HomeScreen({Key? key, required this.authService}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _userInfo;
  Map<String, dynamic>? _sessionStatus;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _updateSessionStatus();
    
    // Update session status every 30 seconds
    Stream.periodic(Duration(seconds: 30)).listen((_) {
      if (mounted) {
        _updateSessionStatus();
      }
    });
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await widget.authService.getCurrentUser();
    setState(() {
      _userInfo = userInfo;
    });
  }

  void _updateSessionStatus() {
    final status = widget.authService.getSessionStatus();
    setState(() {
      _sessionStatus = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('OneGate Home')),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _showSessionDetails,
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _forceTokenRefresh,
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _performLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWelcomeCard(),
            SizedBox(height: 16),
            _buildSessionStatusCard(),
            SizedBox(height: 16),
            _buildActionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.green[700]),
                SizedBox(width: 8),
                Text(
                  context.tr('Welcome!'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (_userInfo != null) ...[
              Text(
                context.tr(
                  'Name: {value}',
                  params: {'value': '${_userInfo!['name'] ?? 'N/A'}'},
                ),
              ),
              Text(
                context.tr(
                  'Email: {value}',
                  params: {'value': '${_userInfo!['email'] ?? 'N/A'}'},
                ),
              ),
              Text(
                context.tr(
                  'Username: {value}',
                  params: {'value': '${_userInfo!['preferred_username'] ?? 'N/A'}'},
                ),
              ),
            ] else
              Text(context.tr('Loading user information...')),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionStatusCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer, color: Colors.blue[700]),
                SizedBox(width: 8),
                Text(
                  context.tr('Session Status'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (_sessionStatus != null) ...[
              _buildStatusItem(
                context.tr('Indefinite Sessions'),
                _sessionStatus!['indefinite_sessions_enabled']
                    ? context.tr('Enabled')
                    : context.tr('Disabled'),
                _sessionStatus!['indefinite_sessions_enabled'] ? Colors.green : Colors.red,
              ),
              _buildStatusItem(
                context.tr('Background Refresh'),
                _sessionStatus!['background_refresh_active']
                    ? context.tr('Active')
                    : context.tr('Inactive'),
                _sessionStatus!['background_refresh_active'] ? Colors.green : Colors.orange,
              ),
              _buildStatusItem(
                context.tr('Consecutive Failures'),
                '${_sessionStatus!['consecutive_failures']}',
                _sessionStatus!['consecutive_failures'] == 0 ? Colors.green : Colors.red,
              ),
            ] else
              Text(context.tr('Loading session status...')),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.purple[700]),
                SizedBox(width: 8),
                Text(
                  context.tr('Actions'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _testApiCall,
              child: Text(context.tr('Test API Call')),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _forceTokenRefresh,
              child: Text(context.tr('Force Token Refresh')),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _showSessionDetails,
              child: Text(context.tr('Show Session Details')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testApiCall() async {
    try {
      // This will automatically handle token refresh if needed
      final token = await widget.authService.getValidAccessToken();
      if (token != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Valid token available')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('No valid token available')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('API test failed: {error}', params: {'error': '$e'}),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _forceTokenRefresh() async {
    try {
      final success = await widget.authService.forceTokenRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? context.tr('Token refresh successful')
                : context.tr('Token refresh failed'),
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      _updateSessionStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Force refresh error: {error}', params: {'error': '$e'}),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSessionDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Session Details')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Automatic token refresh every 2-3 minutes')),
              SizedBox(height: 8),
              Text(context.tr('Secure token storage with encryption')),
              SizedBox(height: 8),
              Text(context.tr('No session timeouts or expiry modals')),
              SizedBox(height: 8),
              Text(context.tr('Persistent sessions across app restarts')),
              SizedBox(height: 16),
              if (_sessionStatus != null) ...[
                Text(
                  context.tr('Current Status:'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  context.tr(
                    'Indefinite Sessions: {value}',
                    params: {'value': '${_sessionStatus!['indefinite_sessions_enabled']}'},
                  ),
                ),
                Text(
                  context.tr(
                    'Background Refresh: {value}',
                    params: {'value': '${_sessionStatus!['background_refresh_active']}'},
                  ),
                ),
                Text(
                  context.tr(
                    'Consecutive Failures: {value}',
                    params: {'value': '${_sessionStatus!['consecutive_failures']}'},
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('OK')),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      await widget.authService.logout();
      // Navigation handled automatically by StreamBuilder
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Logout failed: {error}', params: {'error': '$e'}),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
