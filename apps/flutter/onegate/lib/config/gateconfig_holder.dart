import 'package:flutter_onegate/config/gate_config.dart' show GateConfig;

class GateConfigHolder {
  static late GateConfig _config;

  static void setConfig(GateConfig config) {
    _config = config;
  }

  static String get gateBaseUrl => _config.gateBaseUrl;
  // static String get societyBaseUrl => _config.societyBaseUrl;
}