import '../src/config/intercom_module_config.dart';

class AppConstants {
  static String get callServiceBaseUrl =>
      IntercomModule.config.endpoints.callServiceBaseUrl;

  static String get roomServiceBaseUrl =>
      IntercomModule.config.endpoints.roomServiceBaseUrl;

  static String get jitsiServerUrl => IntercomModule.config.endpoints.jitsiServerUrl;
}
