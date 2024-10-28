
import 'one_gate_platform_interface.dart';

class OneGate {
  Future<String?> getPlatformVersion() {
    return OneGatePlatform.instance.getPlatformVersion();
  }
}
