import 'package:keycloak_wrapper/keycloak_wrapper.dart';

class KeycloakConfigManager {
  static const String bundleIdentifier = 'com.cubeonebiz.gate';
  static const String clientId = 'onegate-sso';
  static const String frontendUrl = 'https://stgsso.cubeone.in';
  static const String realm = 'fstech';
  static const String clientSecret = 'zXpmFL8WzkDoL379FesFl2pgm8vxPa58';

  static KeycloakConfig getConfig() {
    return KeycloakConfig(
      bundleIdentifier: bundleIdentifier,
      clientId: clientId,
      frontendUrl: frontendUrl,
      realm: realm,
      clientSecret: clientSecret,
    );
  }
}
