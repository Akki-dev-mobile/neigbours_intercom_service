import 'package:flutter_onegate/config/gate_config.dart' show GateConfig;

class GateConfigHolder {
  static GateConfig? _config;

  static void setConfig(GateConfig config) {
    _config = config;
  }

  static String get gateBaseUrl =>
      _config?.gateBaseUrl ?? 'https://gateapi.cubeone.in/api';
  /// When config is not set (e.g. fetch failed) we default to native login.
  static bool get useNativeLogin => _config?.useNativeLogin ?? true;
}