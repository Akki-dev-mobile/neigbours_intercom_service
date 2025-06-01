import 'dart:io';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

class AppAuthConfigManager {
  static const String bundleIdentifier = 'com.cubeonebiz.gate';
  // static const String clientId = 'onegate-sso';
  static const String clientId = 'flutter-dummy';
  static const String frontendUrl = 'https://stgsso.cubeone.in';
  static const String realm = 'fstech';
  // static const String clientSecret = 'zXpmFL8WzkDoL379FesFl2pgm8vxPa58';
  static const String clientSecret = 'htBm6RGbbZGzQ5cCaXUSUwGDSnLqWQHa';

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

  /// Debug logging method to display all configuration details
  static void logClientConfiguration({bool includeSecret = false}) {
    print('🔐 ===== KEYCLOAK CLIENT CONFIGURATION DEBUG =====');
    print('📋 Client Details:');
    print('   • Client ID: $clientId');
    print('   • Bundle Identifier: $bundleIdentifier');
    print('   • Frontend URL: $frontendUrl');
    print('   • Realm: $realm');

    if (includeSecret) {
      print(
          '   • Client Secret: ${clientSecret.isNotEmpty ? "${clientSecret.substring(0, 8)}..." : "NOT SET"}');
      print(
          '   • Client Type: ${clientSecret.isNotEmpty ? "CONFIDENTIAL" : "PUBLIC"}');
    } else {
      print('   • Client Secret: [HIDDEN - set includeSecret=true to show]');
      print(
          '   • Client Type: ${clientSecret.isNotEmpty ? "CONFIDENTIAL" : "PUBLIC"}');
    }

    print('🌐 OAuth/OIDC Endpoints:');
    print('   • Authorization: $authorizationEndpoint');
    print('   • Token: $tokenEndpoint');
    print('   • UserInfo: $userInfoEndpoint');
    print('   • End Session: $endSessionEndpoint');

    print('🔗 Redirect URIs:');
    print('   • Login Callback: $redirectUrl');
    print('   • Logout Callback: $postLogoutRedirectUrl');

    print('🔑 OAuth Scopes: ${scopes.join(", ")}');
    print('🔐 ============================================');
  }

  static AuthorizationServiceConfiguration getServiceConfiguration() {
    // Allow self-signed certificates in debug mode
    if (kDebugMode) {
      HttpOverrides.global = MyHttpOverrides();
    }

    return AuthorizationServiceConfiguration(
      authorizationEndpoint: authorizationEndpoint,
      tokenEndpoint: tokenEndpoint,
      endSessionEndpoint: endSessionEndpoint,
    );
  }

  static AuthorizationRequest getAuthorizationRequest() {
    print('🚀 Creating Authorization Request:');
    print('   • Client ID: $clientId');
    print('   • Redirect URL: $redirectUrl');
    print('   • Scopes: ${scopes.join(", ")}');
    print('   • Additional Parameters: access_type=offline');
    print('   • Prompt Values: login');
    print('   • PKCE: Enabled (handled automatically by flutter_appauth)');

    return AuthorizationRequest(
      clientId,
      redirectUrl,
      serviceConfiguration: getServiceConfiguration(),
      scopes: scopes,
      additionalParameters: {
        'access_type': 'offline',
      },
      // Enable PKCE for security
      promptValues: ['login'],
    );
  }

  static TokenRequest getTokenRequest(String authorizationCode,
      {String? codeVerifier}) {
    print('🔄 Creating Token Request:');
    print('   • Client ID: $clientId');
    print('   • Redirect URL: $redirectUrl');
    print('   • Authorization Code: ${authorizationCode.substring(0, 10)}...');
    print(
        '   • Code Verifier: ${codeVerifier != null ? "${codeVerifier.substring(0, 10)}..." : "NOT PROVIDED"}');
    print('   • Client Secret: INCLUDED (${clientSecret.substring(0, 8)}...)');
    print('   • Client Type: CONFIDENTIAL (with PKCE)');

    return TokenRequest(
      clientId,
      redirectUrl,
      authorizationCode: authorizationCode,
      serviceConfiguration: getServiceConfiguration(),
      // Include client secret for confidential clients
      clientSecret: clientSecret,
      codeVerifier: codeVerifier,
    );
  }

  static TokenRequest getRefreshTokenRequest(String refreshToken) {
    return TokenRequest(
      clientId,
      redirectUrl,
      refreshToken: refreshToken,
      serviceConfiguration: getServiceConfiguration(),
      // Include client secret for confidential clients
      clientSecret: clientSecret,
    );
  }
}

// Custom HTTP overrides to accept all certificates in debug mode
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

// Legacy compatibility - will be removed after migration
class KeycloakConfigManager {
  static const String bundleIdentifier = AppAuthConfigManager.bundleIdentifier;
  static const String clientId = AppAuthConfigManager.clientId;
  static const String frontendUrl = AppAuthConfigManager.frontendUrl;
  static const String realm = AppAuthConfigManager.realm;
  static const String clientSecret = AppAuthConfigManager.clientSecret;

  @Deprecated("Use AppAuthConfigManager instead")
  static KeycloakConfigLegacy getConfig() {
    return const KeycloakConfigLegacy(
      bundleIdentifier: bundleIdentifier,
      clientId: clientId,
      frontendUrl: frontendUrl,
      realm: realm,
      clientSecret: clientSecret,
    );
  }
}

// Legacy config class for backward compatibility
class KeycloakConfigLegacy {
  final String bundleIdentifier;
  final String clientId;
  final String frontendUrl;
  final String realm;
  final String clientSecret;

  const KeycloakConfigLegacy({
    required this.bundleIdentifier,
    required this.clientId,
    required this.frontendUrl,
    required this.realm,
    required this.clientSecret,
  });
}
