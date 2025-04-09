import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:keycloak_wrapper/keycloak_wrapper.dart';

class KeycloakConfigManager {
  static const String bundleIdentifier = 'com.cubeonebiz.gate';
  static const String clientId = 'onegate-sso';
  static const String frontendUrl = 'https://stgsso.cubeone.in';
  static const String realm = 'fstech';
  static const String clientSecret = 'zXpmFL8WzkDoL379FesFl2pgm8vxPa58';

  static KeycloakConfig getConfig() {
    // Allow self-signed certificates in debug mode
    if (kDebugMode) {
      HttpOverrides.global = MyHttpOverrides();
    }

    return KeycloakConfig(
      bundleIdentifier: bundleIdentifier,
      clientId: clientId,
      frontendUrl: frontendUrl,
      realm: realm,
      clientSecret: clientSecret,
      // allowInsecureConnections:
      //     true, // Allow connections to servers with self-signed certificates
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
