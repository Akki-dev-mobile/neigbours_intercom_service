import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'one_gate_platform_interface.dart';

/// An implementation of [OneGatePlatform] that uses method channels.
class MethodChannelOneGate extends OneGatePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('one_gate');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
