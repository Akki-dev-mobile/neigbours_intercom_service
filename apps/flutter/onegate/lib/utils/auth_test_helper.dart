import 'dart:developer';
import 'package:flutter_onegate/data/datasources/enhanced_keycloak_config.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_auth_service.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/utils/auth_debug_tool.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:get_it/get_it.dart';

/// Simple authentication test helper
class AuthTestHelper {
  
  /// Run comprehensive authentication test
  static Future<void> runAuthenticationTest() async {
    log('🔍 ===== STARTING AUTHENTICATION TEST =====');
    
    try {
      // Step 1: Run diagnostics
      log('📋 Step 1: Running diagnostics...');
      final diagnostics = await AuthDebugTool.runDiagnostics();
      AuthDebugTool.printDiagnosticsReport(diagnostics);
      
      final summary = diagnostics['summary'] as Map<String, dynamic>;
      final issues = summary['issues'] as List<String>;
      
      if (issues.isNotEmpty) {
        log('❌ Critical issues found. Fix these before testing authentication:');
        for (final issue in issues) {
          log('   • $issue');
        }
        return;
      }
      
      // Step 2: Test current AuthService
      log('🔐 Step 2: Testing current AuthService...');
      await _testCurrentAuthService();
      
      // Step 3: Test enhanced AuthService
      log('🔐 Step 3: Testing enhanced AuthService...');
      await _testEnhancedAuthService();
      
    } catch (e) {
      log('❌ Authentication test failed: $e');
    }
    
    log('✅ ===== AUTHENTICATION TEST COMPLETED =====');
  }
  
  /// Test current AuthService
  static Future<void> _testCurrentAuthService() async {
    try {
      final authService = GetIt.I<AuthService>();
      
      log('🔐 Testing current AuthService login...');
      final result = await authService.login();
      
      if (result != null) {
        log('✅ Current AuthService: SUCCESS');
        log('👤 User: ${result['preferred_username']}');
        log('📧 Email: ${result['email']}');
      } else {
        log('❌ Current AuthService: FAILED - No result returned');
      }
    } catch (e) {
      log('❌ Current AuthService: ERROR - $e');
      _analyzeAuthError(e);
    }
  }
  
  /// Test enhanced AuthService
  static Future<void> _testEnhancedAuthService() async {
    try {
      final enhancedAuthService = EnhancedAuthService(
        gateStorage: GetIt.I<GateStorage>(),
        remoteDataSource: GetIt.I<RemoteDataSource>(),
      );
      
      await enhancedAuthService.initialize();
      
      log('🔐 Testing enhanced AuthService login...');
      final result = await enhancedAuthService.login();
      
      if (result != null) {
        log('✅ Enhanced AuthService: SUCCESS');
        log('👤 User: ${result['preferred_username']}');
        log('📧 Email: ${result['email']}');
      } else {
        log('❌ Enhanced AuthService: FAILED - No result returned');
      }
    } catch (e) {
      log('❌ Enhanced AuthService: ERROR - $e');
      _analyzeAuthError(e);
    }
  }
  
  /// Analyze authentication error and provide specific guidance
  static void _analyzeAuthError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    log('🔍 ===== ERROR ANALYSIS =====');
    
    if (errorString.contains('unauthorized_client')) {
      log('🔍 ISSUE: Unauthorized Client');
      log('🔧 IMMEDIATE FIXES:');
      log('   1. Check Keycloak client "onegate-sso" exists in realm "fstech"');
      log('   2. Verify client is enabled');
      log('   3. Check redirect URI: com.cubeonebiz.gate://login-callback');
      log('   4. Verify client access type (public vs confidential)');
      
    } else if (errorString.contains('invalid_client')) {
      log('🔍 ISSUE: Invalid Client');
      log('🔧 IMMEDIATE FIXES:');
      log('   1. If confidential client: Check client secret');
      log('   2. If public client: Remove client secret from config');
      log('   3. Try switching client access type in Keycloak');
      
    } else if (errorString.contains('redirect_uri')) {
      log('🔍 ISSUE: Redirect URI Mismatch');
      log('🔧 IMMEDIATE FIXES:');
      log('   1. Add "com.cubeonebiz.gate://login-callback" to Keycloak Valid Redirect URIs');
      log('   2. Check Android manifest intent filter');
      
    } else if (errorString.contains('pkce')) {
      log('🔍 ISSUE: PKCE Configuration');
      log('🔧 IMMEDIATE FIXES:');
      log('   1. Enable PKCE in Keycloak client settings');
      log('   2. Set Code Challenge Method to S256');
      
    } else if (errorString.contains('network') || errorString.contains('connection')) {
      log('🔍 ISSUE: Network/Connectivity');
      log('🔧 IMMEDIATE FIXES:');
      log('   1. Check internet connection');
      log('   2. Verify Keycloak server is accessible');
      log('   3. Check SSL certificate issues');
      
    } else {
      log('🔍 ISSUE: General Authentication Error');
      log('🔧 GENERAL TROUBLESHOOTING:');
      log('   1. Check all Keycloak client settings');
      log('   2. Verify network connectivity');
      log('   3. Review authentication logs');
    }
    
    log('🔍 ========================');
  }
  
  /// Quick configuration check
  static void checkConfiguration() {
    log('🔧 ===== CONFIGURATION CHECK =====');
    
    EnhancedKeycloakConfig.printConfigurationReport();
    
    final validation = EnhancedKeycloakConfig.validateConfiguration();
    final isValid = validation['isValid'] as bool;
    
    if (!isValid) {
      final issues = validation['issues'] as List<String>;
      log('❌ Configuration issues found:');
      for (final issue in issues) {
        log('   • $issue');
      }
    } else {
      log('✅ Configuration is valid');
    }
    
    log('🔧 ============================');
  }
  
  /// Test network connectivity to Keycloak
  static Future<void> testConnectivity() async {
    log('🌐 ===== CONNECTIVITY TEST =====');
    
    final connectivity = await EnhancedKeycloakConfig.testEndpointConnectivity();
    
    log('📡 Endpoint Connectivity:');
    connectivity.forEach((endpoint, isReachable) {
      log('   • $endpoint: ${isReachable ? '✅ OK' : '❌ FAILED'}');
    });
    
    final failedEndpoints = connectivity.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();
    
    if (failedEndpoints.isNotEmpty) {
      log('❌ Failed endpoints: ${failedEndpoints.join(', ')}');
      log('🔧 Check network connection and Keycloak server status');
    } else {
      log('✅ All endpoints are reachable');
    }
    
    log('🌐 ========================');
  }
  
  /// Print Keycloak client configuration checklist
  static void printKeycloakChecklist() {
    log('📋 ===== KEYCLOAK CLIENT CHECKLIST =====');
    log('');
    log('🔧 Required Keycloak Client Settings:');
    log('   □ Client ID: onegate-sso');
    log('   □ Client enabled: true');
    log('   □ Client protocol: openid-connect');
    log('   □ Access type: public (recommended) or confidential');
    log('   □ Standard flow enabled: true');
    log('   □ Direct access grants enabled: true');
    log('   □ Valid Redirect URIs: com.cubeonebiz.gate://login-callback');
    log('   □ Web Origins: * (or specific origins)');
    log('');
    log('🔧 Advanced Settings (if supported):');
    log('   □ Proof Key for Code Exchange Code Challenge Method: S256');
    log('   □ Access Token Lifespan: 5 minutes (or as needed)');
    log('');
    log('🔧 Realm Settings:');
    log('   □ Realm: fstech');
    log('   □ Realm enabled: true');
    log('');
    log('📋 ================================');
  }
}
