import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_onegate/data/datasources/enhanced_keycloak_config.dart';

/// Comprehensive authentication debugging tool
class AuthDebugTool {
  
  /// Run comprehensive authentication diagnostics
  static Future<Map<String, dynamic>> runDiagnostics() async {
    log('🔍 ===== RUNNING AUTHENTICATION DIAGNOSTICS =====');
    
    final results = <String, dynamic>{};
    
    // 1. Configuration validation
    log('📋 Step 1: Validating configuration...');
    results['configuration'] = EnhancedKeycloakConfig.validateConfiguration();
    
    // 2. Network connectivity
    log('🌐 Step 2: Testing network connectivity...');
    results['connectivity'] = await _testNetworkConnectivity();
    
    // 3. Keycloak server health
    log('🏥 Step 3: Checking Keycloak server health...');
    results['serverHealth'] = await _checkKeycloakServerHealth();
    
    // 4. Client configuration
    log('🔧 Step 4: Validating client configuration...');
    results['clientConfig'] = await _validateClientConfiguration();
    
    // 5. Redirect URI validation
    log('🔗 Step 5: Validating redirect URI configuration...');
    results['redirectUri'] = await _validateRedirectUriConfiguration();
    
    // 6. SSL/TLS validation
    log('🔒 Step 6: Validating SSL/TLS configuration...');
    results['ssl'] = await _validateSslConfiguration();
    
    // Generate summary report
    results['summary'] = _generateSummaryReport(results);
    
    log('✅ Diagnostics completed');
    return results;
  }

  /// Test basic network connectivity
  static Future<Map<String, dynamic>> _testNetworkConnectivity() async {
    final results = <String, dynamic>{};
    
    try {
      // Test basic internet connectivity
      final response = await http.get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 10));
      results['internet'] = response.statusCode == 200;
    } catch (e) {
      results['internet'] = false;
      results['internetError'] = e.toString();
    }
    
    // Test Keycloak server connectivity
    results['keycloakEndpoints'] = await EnhancedKeycloakConfig.testEndpointConnectivity();
    
    return results;
  }

  /// Check Keycloak server health
  static Future<Map<String, dynamic>> _checkKeycloakServerHealth() async {
    final results = <String, dynamic>{};
    
    try {
      // Test Keycloak health endpoint
      final healthUrl = '${EnhancedKeycloakConfig.frontendUrl}/health';
      final response = await http.get(Uri.parse(healthUrl))
          .timeout(const Duration(seconds: 10));
      
      results['healthEndpoint'] = {
        'accessible': true,
        'statusCode': response.statusCode,
        'response': response.body,
      };
    } catch (e) {
      results['healthEndpoint'] = {
        'accessible': false,
        'error': e.toString(),
      };
    }
    
    try {
      // Test realm endpoint
      final realmUrl = '${EnhancedKeycloakConfig.frontendUrl}/realms/${EnhancedKeycloakConfig.realm}';
      final response = await http.get(Uri.parse(realmUrl))
          .timeout(const Duration(seconds: 10));
      
      results['realmEndpoint'] = {
        'accessible': response.statusCode == 200,
        'statusCode': response.statusCode,
      };
      
      if (response.statusCode == 200) {
        final realmInfo = jsonDecode(response.body);
        results['realmInfo'] = {
          'realm': realmInfo['realm'],
          'public_key': realmInfo['public_key'] != null,
          'token-service': realmInfo['token-service'],
          'account-service': realmInfo['account-service'],
        };
      }
    } catch (e) {
      results['realmEndpoint'] = {
        'accessible': false,
        'error': e.toString(),
      };
    }
    
    return results;
  }

  /// Validate client configuration
  static Future<Map<String, dynamic>> _validateClientConfiguration() async {
    final results = <String, dynamic>{};
    
    try {
      // Test OIDC configuration endpoint
      final oidcConfigUrl = '${EnhancedKeycloakConfig.frontendUrl}/realms/${EnhancedKeycloakConfig.realm}/.well-known/openid_configuration';
      final response = await http.get(Uri.parse(oidcConfigUrl))
          .timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final oidcConfig = jsonDecode(response.body);
        results['oidcConfiguration'] = {
          'accessible': true,
          'issuer': oidcConfig['issuer'],
          'authorization_endpoint': oidcConfig['authorization_endpoint'],
          'token_endpoint': oidcConfig['token_endpoint'],
          'userinfo_endpoint': oidcConfig['userinfo_endpoint'],
          'end_session_endpoint': oidcConfig['end_session_endpoint'],
          'code_challenge_methods_supported': oidcConfig['code_challenge_methods_supported'],
          'pkce_supported': oidcConfig['code_challenge_methods_supported']?.contains('S256') ?? false,
        };
        
        // Validate our endpoints match OIDC configuration
        results['endpointValidation'] = {
          'authorization_match': oidcConfig['authorization_endpoint'] == EnhancedKeycloakConfig.authorizationEndpoint,
          'token_match': oidcConfig['token_endpoint'] == EnhancedKeycloakConfig.tokenEndpoint,
          'userinfo_match': oidcConfig['userinfo_endpoint'] == EnhancedKeycloakConfig.userInfoEndpoint,
          'end_session_match': oidcConfig['end_session_endpoint'] == EnhancedKeycloakConfig.endSessionEndpoint,
        };
      } else {
        results['oidcConfiguration'] = {
          'accessible': false,
          'statusCode': response.statusCode,
          'error': response.body,
        };
      }
    } catch (e) {
      results['oidcConfiguration'] = {
        'accessible': false,
        'error': e.toString(),
      };
    }
    
    return results;
  }

  /// Validate redirect URI configuration
  static Future<Map<String, dynamic>> _validateRedirectUriConfiguration() async {
    final results = <String, dynamic>{};
    
    // Check redirect URI format
    final redirectUri = EnhancedKeycloakConfig.redirectUrl;
    results['format'] = {
      'valid': redirectUri.contains('://'),
      'scheme': redirectUri.split('://').first,
      'host': redirectUri.contains('://') ? redirectUri.split('://')[1].split('/').first : null,
      'path': redirectUri.contains('://') ? redirectUri.split('://')[1].substring(redirectUri.split('://')[1].indexOf('/')) : null,
    };
    
    // Check if scheme matches bundle identifier
    results['schemeMatch'] = redirectUri.startsWith(EnhancedKeycloakConfig.bundleIdentifier);
    
    return results;
  }

  /// Validate SSL/TLS configuration
  static Future<Map<String, dynamic>> _validateSslConfiguration() async {
    final results = <String, dynamic>{};
    
    try {
      final uri = Uri.parse(EnhancedKeycloakConfig.frontendUrl);
      final socket = await SecureSocket.connect(
        uri.host,
        uri.port == 0 ? 443 : uri.port,
        timeout: const Duration(seconds: 10),
      );
      
      results['sslConnection'] = {
        'successful': true,
        'certificate': {
          'subject': socket.peerCertificate?.subject,
          'issuer': socket.peerCertificate?.issuer,
          'startValidity': socket.peerCertificate?.startValidity?.toIso8601String(),
          'endValidity': socket.peerCertificate?.endValidity?.toIso8601String(),
        },
      };
      
      socket.close();
    } catch (e) {
      results['sslConnection'] = {
        'successful': false,
        'error': e.toString(),
      };
    }
    
    return results;
  }

  /// Generate summary report
  static Map<String, dynamic> _generateSummaryReport(Map<String, dynamic> results) {
    final issues = <String>[];
    final warnings = <String>[];
    final recommendations = <String>[];
    
    // Check configuration
    final config = results['configuration'] as Map<String, dynamic>;
    if (!(config['isValid'] as bool)) {
      issues.addAll((config['issues'] as List<String>));
    }
    warnings.addAll((config['warnings'] as List<String>));
    
    // Check connectivity
    final connectivity = results['connectivity'] as Map<String, dynamic>;
    if (!(connectivity['internet'] as bool)) {
      issues.add('No internet connectivity');
    }
    
    final keycloakEndpoints = connectivity['keycloakEndpoints'] as Map<String, bool>;
    final unreachableEndpoints = keycloakEndpoints.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();
    
    if (unreachableEndpoints.isNotEmpty) {
      issues.add('Unreachable Keycloak endpoints: ${unreachableEndpoints.join(', ')}');
    }
    
    // Check server health
    final serverHealth = results['serverHealth'] as Map<String, dynamic>;
    final realmEndpoint = serverHealth['realmEndpoint'] as Map<String, dynamic>;
    if (!(realmEndpoint['accessible'] as bool)) {
      issues.add('Keycloak realm endpoint not accessible');
    }
    
    // Check client configuration
    final clientConfig = results['clientConfig'] as Map<String, dynamic>;
    final oidcConfig = clientConfig['oidcConfiguration'] as Map<String, dynamic>;
    if (!(oidcConfig['accessible'] as bool)) {
      issues.add('OIDC configuration endpoint not accessible');
    } else {
      final pkceSupported = oidcConfig['pkce_supported'] as bool? ?? false;
      if (!pkceSupported) {
        warnings.add('PKCE not supported by Keycloak server');
        recommendations.add('Enable PKCE support in Keycloak client settings');
      }
    }
    
    // Check SSL
    final ssl = results['ssl'] as Map<String, dynamic>;
    final sslConnection = ssl['sslConnection'] as Map<String, dynamic>;
    if (!(sslConnection['successful'] as bool)) {
      warnings.add('SSL/TLS connection issues detected');
    }
    
    // Generate overall status
    final hasIssues = issues.isNotEmpty;
    final hasWarnings = warnings.isNotEmpty;
    
    String overallStatus;
    if (hasIssues) {
      overallStatus = 'CRITICAL_ISSUES';
    } else if (hasWarnings) {
      overallStatus = 'WARNINGS';
    } else {
      overallStatus = 'HEALTHY';
    }
    
    return {
      'overallStatus': overallStatus,
      'issues': issues,
      'warnings': warnings,
      'recommendations': recommendations,
      'summary': {
        'totalIssues': issues.length,
        'totalWarnings': warnings.length,
        'totalRecommendations': recommendations.length,
      },
    };
  }

  /// Print comprehensive diagnostics report
  static void printDiagnosticsReport(Map<String, dynamic> results) {
    log('📊 ===== AUTHENTICATION DIAGNOSTICS REPORT =====');
    
    final summary = results['summary'] as Map<String, dynamic>;
    final overallStatus = summary['overallStatus'] as String;
    
    // Print overall status
    switch (overallStatus) {
      case 'HEALTHY':
        log('✅ OVERALL STATUS: HEALTHY');
        break;
      case 'WARNINGS':
        log('⚠️ OVERALL STATUS: WARNINGS DETECTED');
        break;
      case 'CRITICAL_ISSUES':
        log('❌ OVERALL STATUS: CRITICAL ISSUES DETECTED');
        break;
    }
    
    // Print issues
    final issues = summary['issues'] as List<String>;
    if (issues.isNotEmpty) {
      log('❌ CRITICAL ISSUES:');
      for (final issue in issues) {
        log('   • $issue');
      }
    }
    
    // Print warnings
    final warnings = summary['warnings'] as List<String>;
    if (warnings.isNotEmpty) {
      log('⚠️ WARNINGS:');
      for (final warning in warnings) {
        log('   • $warning');
      }
    }
    
    // Print recommendations
    final recommendations = summary['recommendations'] as List<String>;
    if (recommendations.isNotEmpty) {
      log('💡 RECOMMENDATIONS:');
      for (final recommendation in recommendations) {
        log('   • $recommendation');
      }
    }
    
    log('📊 ============================================');
  }
}
