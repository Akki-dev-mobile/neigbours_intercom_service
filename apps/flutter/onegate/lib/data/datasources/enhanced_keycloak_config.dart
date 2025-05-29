import 'dart:io';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

/// Enhanced Keycloak configuration with comprehensive debugging and multiple client type support
class EnhancedKeycloakConfig {
  static const String bundleIdentifier = 'com.cubeonebiz.gate';
  static const String clientId = 'onegate-sso';
  static const String frontendUrl = 'https://stgsso.cubeone.in';
  static const String realm = 'fstech';
  static const String clientSecret = 'zXpmFL8WzkDoL379FesFl2pgm8vxPa58';

  // OAuth/OIDC endpoints
  static String get authorizationEndpoint =>
      '$frontendUrl/realms/$realm/protocol/openid-connect/auth';
  static String get tokenEndpoint =>
      '$frontendUrl/realms/$realm/protocol/openid-connect/token';
  static String get userInfoEndpoint =>
      '$frontendUrl/realms/$realm/protocol/openid-connect/userinfo';
  static String get endSessionEndpoint =>
      '$frontendUrl/realms/$realm/protocol/openid-connect/logout';

  // Redirect URIs
  static String get redirectUrl => '$bundleIdentifier://login-callback';
  static String get postLogoutRedirectUrl =>
      '$bundleIdentifier://logout-callback';

  // Scopes
  static const List<String> scopes = ['openid', 'profile', 'email'];

  /// Client type configuration
  static bool get isConfidentialClient => clientSecret.isNotEmpty;
  static bool get isPublicClient => !isConfidentialClient;

  /// Get service configuration with enhanced error handling
  static AuthorizationServiceConfiguration getServiceConfiguration() {
    // Allow self-signed certificates in debug mode
    if (kDebugMode) {
      HttpOverrides.global = _MyHttpOverrides();
    }

    log('🔧 Creating service configuration:');
    log('   • Authorization Endpoint: $authorizationEndpoint');
    log('   • Token Endpoint: $tokenEndpoint');
    log('   • End Session Endpoint: $endSessionEndpoint');

    return AuthorizationServiceConfiguration(
      authorizationEndpoint: authorizationEndpoint,
      tokenEndpoint: tokenEndpoint,
      endSessionEndpoint: endSessionEndpoint,
    );
  }

  /// Create authorization token request for confidential clients
  static AuthorizationTokenRequest createConfidentialClientRequest() {
    log('🔐 Creating CONFIDENTIAL client authorization request');
    log('   • Client ID: $clientId');
    log('   • Redirect URL: $redirectUrl');
    log('   • Scopes: ${scopes.join(", ")}');
    log('   • Client Secret: PROVIDED');
    log('   • PKCE: Enabled (automatic)');

    return AuthorizationTokenRequest(
      clientId,
      redirectUrl,
      serviceConfiguration: getServiceConfiguration(),
      scopes: scopes,
      clientSecret: clientSecret,
      additionalParameters: {
        'access_type': 'offline',
      },
    );
  }

  /// Create authorization token request for public clients (no client secret)
  static AuthorizationTokenRequest createPublicClientRequest() {
    log('🔓 Creating PUBLIC client authorization request');
    log('   • Client ID: $clientId');
    log('   • Redirect URL: $redirectUrl');
    log('   • Scopes: ${scopes.join(", ")}');
    log('   • Client Secret: NOT PROVIDED (public client)');
    log('   • PKCE: Enabled (automatic)');

    return AuthorizationTokenRequest(
      clientId,
      redirectUrl,
      serviceConfiguration: getServiceConfiguration(),
      scopes: scopes,
      // No client secret for public clients
      additionalParameters: {
        'access_type': 'offline',
      },
    );
  }

  /// Create authorization token request based on client type
  static AuthorizationTokenRequest createAuthorizationTokenRequest() {
    if (isConfidentialClient) {
      return createConfidentialClientRequest();
    } else {
      return createPublicClientRequest();
    }
  }

  /// Create refresh token request
  static TokenRequest createRefreshTokenRequest(String refreshToken) {
    log('🔄 Creating refresh token request');
    log('   • Client ID: $clientId');
    log('   • Client Type: ${isConfidentialClient ? "CONFIDENTIAL" : "PUBLIC"}');
    
    if (isConfidentialClient) {
      log('   • Client Secret: PROVIDED');
      return TokenRequest(
        clientId,
        redirectUrl,
        refreshToken: refreshToken,
        serviceConfiguration: getServiceConfiguration(),
        clientSecret: clientSecret,
      );
    } else {
      log('   • Client Secret: NOT PROVIDED (public client)');
      return TokenRequest(
        clientId,
        redirectUrl,
        refreshToken: refreshToken,
        serviceConfiguration: getServiceConfiguration(),
      );
    }
  }

  /// Comprehensive configuration validation
  static Map<String, dynamic> validateConfiguration() {
    final issues = <String>[];
    final warnings = <String>[];
    final info = <String>[];

    // Check basic configuration
    if (clientId.isEmpty) {
      issues.add('Client ID is empty');
    }
    if (frontendUrl.isEmpty) {
      issues.add('Frontend URL is empty');
    }
    if (realm.isEmpty) {
      issues.add('Realm is empty');
    }
    if (bundleIdentifier.isEmpty) {
      issues.add('Bundle identifier is empty');
    }

    // Check client type configuration
    if (isConfidentialClient) {
      info.add('Client configured as CONFIDENTIAL (with secret)');
      if (clientSecret.length < 32) {
        warnings.add('Client secret seems short (${clientSecret.length} chars)');
      }
    } else {
      info.add('Client configured as PUBLIC (no secret)');
      warnings.add('Public client configuration - ensure PKCE is enabled in Keycloak');
    }

    // Check redirect URI format
    if (!redirectUrl.contains('://')) {
      issues.add('Redirect URL format invalid: $redirectUrl');
    }

    // Check endpoint URLs
    try {
      Uri.parse(authorizationEndpoint);
      Uri.parse(tokenEndpoint);
      Uri.parse(userInfoEndpoint);
      Uri.parse(endSessionEndpoint);
    } catch (e) {
      issues.add('Invalid endpoint URL format: $e');
    }

    return {
      'isValid': issues.isEmpty,
      'issues': issues,
      'warnings': warnings,
      'info': info,
      'clientType': isConfidentialClient ? 'CONFIDENTIAL' : 'PUBLIC',
      'endpoints': {
        'authorization': authorizationEndpoint,
        'token': tokenEndpoint,
        'userInfo': userInfoEndpoint,
        'endSession': endSessionEndpoint,
      },
      'redirectUrls': {
        'login': redirectUrl,
        'logout': postLogoutRedirectUrl,
      },
    };
  }

  /// Print comprehensive configuration report
  static void printConfigurationReport() {
    final validation = validateConfiguration();
    
    log('🔐 ===== ENHANCED KEYCLOAK CONFIGURATION REPORT =====');
    log('📋 Basic Configuration:');
    log('   • Client ID: $clientId');
    log('   • Bundle Identifier: $bundleIdentifier');
    log('   • Frontend URL: $frontendUrl');
    log('   • Realm: $realm');
    log('   • Client Type: ${validation['clientType']}');
    
    if (isConfidentialClient) {
      log('   • Client Secret: ${clientSecret.substring(0, 8)}... (${clientSecret.length} chars)');
    }

    log('🌐 OAuth/OIDC Endpoints:');
    final endpoints = validation['endpoints'] as Map<String, dynamic>;
    endpoints.forEach((key, value) {
      log('   • ${key.toUpperCase()}: $value');
    });

    log('🔗 Redirect URIs:');
    final redirectUrls = validation['redirectUrls'] as Map<String, dynamic>;
    redirectUrls.forEach((key, value) {
      log('   • ${key.toUpperCase()}: $value');
    });

    log('🔑 OAuth Scopes: ${scopes.join(", ")}');

    // Print validation results
    final issues = validation['issues'] as List<String>;
    final warnings = validation['warnings'] as List<String>;
    final info = validation['info'] as List<String>;

    if (issues.isNotEmpty) {
      log('❌ CONFIGURATION ISSUES:');
      for (final issue in issues) {
        log('   • $issue');
      }
    }

    if (warnings.isNotEmpty) {
      log('⚠️ CONFIGURATION WARNINGS:');
      for (final warning in warnings) {
        log('   • $warning');
      }
    }

    if (info.isNotEmpty) {
      log('ℹ️ CONFIGURATION INFO:');
      for (final infoItem in info) {
        log('   • $infoItem');
      }
    }

    log('✅ Configuration Valid: ${validation['isValid']}');
    log('🔐 ================================================');
  }

  /// Test endpoint connectivity
  static Future<Map<String, bool>> testEndpointConnectivity() async {
    final results = <String, bool>{};
    
    final endpoints = {
      'authorization': authorizationEndpoint,
      'token': tokenEndpoint,
      'userInfo': userInfoEndpoint,
      'endSession': endSessionEndpoint,
    };

    for (final entry in endpoints.entries) {
      try {
        final client = HttpClient();
        if (kDebugMode) {
          client.badCertificateCallback = (cert, host, port) => true;
        }
        
        final request = await client.getUrl(Uri.parse(entry.value));
        final response = await request.close();
        results[entry.key] = response.statusCode < 500;
        client.close();
      } catch (e) {
        results[entry.key] = false;
        log('❌ Failed to connect to ${entry.key}: $e');
      }
    }

    return results;
  }
}

/// Custom HTTP overrides for debug mode
class _MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
