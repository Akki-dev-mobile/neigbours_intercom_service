# OneGate Authentication Token Debug System - Integration Guide

## 🎯 **Overview**

The OneGate Authentication Token Debug System provides comprehensive debugging and monitoring capabilities for authentication token state management. This system helps developers and support teams diagnose authentication issues, monitor token health, and ensure proper token management throughout the application lifecycle.

## 🏗️ **Architecture Components**

### **Core Components**

1. **AuthTokenDebugManager** - Main debugging coordinator
2. **AuthTokenDebugModels** - Data models for debug state
3. **AuthTokenDebugWidget** - Reusable debug UI component
4. **DebugAwareAuthInterceptor** - Enhanced API interceptor with debugging
5. **AuthDebugScreen** - Comprehensive debug interface

### **Key Features**

✅ **Real-time Token Monitoring** - Continuous monitoring of token state
✅ **Storage Consistency Checks** - Validates token consistency across storage mechanisms
✅ **Token Analysis** - Comprehensive JWT token analysis and validation
✅ **API Request Debugging** - Detailed logging of authenticated API requests
✅ **Health Status Monitoring** - Overall authentication health assessment
✅ **Debug Actions** - Force refresh, clear tokens, export reports
✅ **Visual Debug Interface** - User-friendly debug screens and widgets

## 🚀 **Integration Steps**

### **1. Initialize Debug Manager in Main App**

```dart
import 'package:flutter_onegate/services/auth_service/auth_token_debug_manager.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _authDebugManager = AuthTokenDebugManager();

  @override
  void initState() {
    super.initState();
    _initializeDebugSystem();
  }

  Future<void> _initializeDebugSystem() async {
    try {
      await _authDebugManager.initialize();
      
      // Enable debugging in development mode
      if (kDebugMode) {
        _authDebugManager.enableDebugging();
      }
      
      print('✅ Auth debug system initialized');
    } catch (e) {
      print('❌ Error initializing auth debug system: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneGate',
      home: HomePage(),
      // Add debug screen route
      routes: {
        '/auth-debug': (context) => const AuthDebugScreen(),
      },
    );
  }

  @override
  void dispose() {
    _authDebugManager.dispose();
    super.dispose();
  }
}
```

### **2. Add Debug Widget to Your App**

#### **Option A: Floating Debug Button (Development Only)**

```dart
import 'package:flutter_onegate/presentation/widgets/auth_token_debug_widget.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('OneGate')),
      body: YourMainContent(),
      // Add floating debug button in development
      floatingActionButton: kDebugMode
          ? FloatingActionButton(
              onPressed: () => _showDebugBottomSheet(context),
              child: Icon(Icons.bug_report),
              backgroundColor: Colors.red,
            )
          : null,
    );
  }

  void _showDebugBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        child: const AuthTokenDebugWidget(
          showFullDetails: true,
          enableActions: true,
        ),
      ),
    );
  }
}
```

#### **Option B: Debug Menu in Settings**

```dart
class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        children: [
          // Your regular settings items
          ListTile(
            title: Text('Profile'),
            onTap: () => _navigateToProfile(context),
          ),
          ListTile(
            title: Text('Notifications'),
            onTap: () => _navigateToNotifications(context),
          ),
          
          // Debug section (only in development)
          if (kDebugMode) ...[
            const Divider(),
            const ListTile(
              title: Text(
                'Debug Options',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.security, color: Colors.blue),
              title: const Text('Authentication Debug'),
              subtitle: const Text('Monitor token state and authentication'),
              onTap: () => Navigator.pushNamed(context, '/auth-debug'),
            ),
            ListTile(
              leading: const Icon(Icons.token, color: Colors.green),
              title: const Text('Quick Token Status'),
              subtitle: const Text('View current token information'),
              onTap: () => _showQuickTokenStatus(context),
            ),
          ],
        ],
      ),
    );
  }

  void _showQuickTokenStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: const AuthTokenDebugWidget(
            showFullDetails: false,
            enableActions: false,
          ),
        ),
      ),
    );
  }
}
```

### **3. Integrate Debug-Aware API Interceptor**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_onegate/services/api_client/debug_aware_auth_interceptor.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://your-api-base-url.com',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // Add debug-aware auth interceptor
    _dio.interceptors.add(DebugAwareAuthInterceptor());

    // Add logging interceptor for additional debugging
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (object) => debugPrint('🌐 API: $object'),
      ));
    }
  }

  // Your API methods
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }
}
```

### **4. Monitor Authentication State**

```dart
import 'package:flutter_onegate/services/auth_service/auth_token_debug_manager.dart';

class AuthMonitoringService {
  final _debugManager = AuthTokenDebugManager();

  Future<void> initialize() async {
    await _debugManager.initialize();
    _debugManager.enableDebugging();

    // Listen to debug state changes
    _debugManager.debugStateStream.listen((state) {
      _handleAuthStateChange(state);
    });
  }

  void _handleAuthStateChange(TokenDebugState state) {
    // Log important state changes
    if (state.healthStatus.needsAttention) {
      print('⚠️ Auth attention needed: ${state.healthStatus.description}');
    }

    // Handle specific conditions
    switch (state.healthStatus) {
      case TokenHealthStatus.needsRefresh:
        print('🔄 Tokens need refresh soon');
        break;
      case TokenHealthStatus.invalid:
        print('❌ Invalid tokens detected');
        break;
      case TokenHealthStatus.inconsistent:
        print('🔄 Storage inconsistency detected');
        break;
      case TokenHealthStatus.noTokens:
        print('🚫 No tokens found');
        break;
      case TokenHealthStatus.error:
        print('💥 Auth error: ${state.error}');
        break;
      case TokenHealthStatus.healthy:
        print('✅ Authentication healthy');
        break;
    }
  }

  // Get current authentication health
  Future<bool> isAuthenticationHealthy() async {
    final state = _debugManager.currentState;
    return state.healthStatus.isHealthy;
  }

  // Force token refresh for debugging
  Future<bool> debugRefreshTokens() async {
    return await _debugManager.forceTokenRefresh();
  }

  // Get debug report
  String getDebugReport() {
    return _debugManager.getFormattedDebugReport();
  }
}
```

## 🔧 **Configuration Options**

### **Debug Configuration**

```dart
import 'package:flutter_onegate/services/auth_service/auth_token_debug_models.dart';

// Development configuration
final devConfig = TokenDebugConfig.development();

// Production configuration (minimal debugging)
final prodConfig = TokenDebugConfig.production();

// Custom configuration
final customConfig = TokenDebugConfig(
  enableRealTimeUpdates: true,
  updateInterval: Duration(seconds: 15),
  enableDetailedLogging: kDebugMode,
  enableStorageConsistencyChecks: true,
  enableTokenValidation: true,
);
```

### **Conditional Debug Features**

```dart
class ConditionalDebugFeatures {
  static bool get isDebugMode => kDebugMode;
  static bool get enableDebugUI => isDebugMode;
  static bool get enableDetailedLogging => isDebugMode;
  static bool get enableDebugActions => isDebugMode;

  // Show debug features based on build mode
  static Widget? buildDebugWidget() {
    if (!enableDebugUI) return null;
    
    return const AuthTokenDebugWidget(
      showFullDetails: true,
      enableActions: true,
    );
  }

  // Add debug menu items
  static List<Widget> buildDebugMenuItems(BuildContext context) {
    if (!enableDebugUI) return [];
    
    return [
      const Divider(),
      ListTile(
        leading: const Icon(Icons.bug_report),
        title: const Text('Auth Debug'),
        onTap: () => Navigator.pushNamed(context, '/auth-debug'),
      ),
    ];
  }
}
```

## 📊 **Monitoring & Analytics**

### **Health Monitoring**

```dart
class AuthHealthMonitor {
  final _debugManager = AuthTokenDebugManager();
  Timer? _healthCheckTimer;

  void startHealthMonitoring() {
    _healthCheckTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      await _performHealthCheck();
    });
  }

  Future<void> _performHealthCheck() async {
    final state = _debugManager.currentState;
    
    // Log health metrics
    final metrics = {
      'health_status': state.healthStatus.toString(),
      'has_tokens': state.hasAnyTokens,
      'is_authenticated': state.isAuthenticated,
      'token_expiry_minutes': state.accessTokenAnalysis?.timeUntilExpiryMinutes,
      'storage_consistent': state.storageConsistency?.isConsistent,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Send to analytics or logging service
    await _sendHealthMetrics(metrics);

    // Alert on critical issues
    if (state.healthStatus == TokenHealthStatus.error) {
      await _alertCriticalAuthIssue(state);
    }
  }

  Future<void> _sendHealthMetrics(Map<String, dynamic> metrics) async {
    // Implement your analytics/logging logic
    print('📊 Auth Health Metrics: $metrics');
  }

  Future<void> _alertCriticalAuthIssue(TokenDebugState state) async {
    // Implement critical issue alerting
    print('🚨 Critical Auth Issue: ${state.error}');
  }

  void dispose() {
    _healthCheckTimer?.cancel();
  }
}
```

## 🎯 **Best Practices**

### **1. Development vs Production**
- Enable full debugging features only in development builds
- Use minimal debugging in production for performance
- Implement feature flags for debug capabilities

### **2. Security Considerations**
- Never log complete tokens in production
- Mask sensitive information in debug outputs
- Ensure debug screens are not accessible in production builds

### **3. Performance Optimization**
- Use appropriate update intervals for real-time monitoring
- Disable debugging when not needed
- Implement efficient state change detection

### **4. Error Handling**
- Gracefully handle debug system failures
- Provide fallback mechanisms when debugging is unavailable
- Log debug system errors separately

## 🔍 **Troubleshooting Common Issues**

### **Token Inconsistency**
```dart
// Check storage consistency
final state = debugManager.currentState;
if (state.storageConsistency?.isConsistent == false) {
  print('Storage issues: ${state.storageConsistency?.issues}');
  // Implement fix logic
}
```

### **Token Expiration Issues**
```dart
// Monitor token expiration
if (state.accessTokenAnalysis?.isExpiringSoon == true) {
  print('Token expiring in ${state.accessTokenAnalysis?.timeUntilExpiryMinutes} minutes');
  await debugManager.forceTokenRefresh();
}
```

### **Authentication Failures**
```dart
// Debug authentication failures
if (!state.isAuthenticated && state.hasAnyTokens) {
  print('Auth failure with tokens present');
  final report = debugManager.getFormattedDebugReport();
  print(report);
}
```

This comprehensive debug system provides complete visibility into the OneGate authentication token state, enabling rapid diagnosis and resolution of authentication issues while maintaining security and performance standards.
