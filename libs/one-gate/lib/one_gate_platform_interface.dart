import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'one_gate_method_channel.dart';

abstract class OneGatePlatform extends PlatformInterface {
  /// Constructs a OneGatePlatform.
  OneGatePlatform() : super(token: _token);

  static final Object _token = Object();

  static OneGatePlatform _instance = MethodChannelOneGate();

  /// The default instance of [OneGatePlatform] to use.
  ///
  /// Defaults to [MethodChannelOneGate].
  static OneGatePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OneGatePlatform] when
  /// they register themselves.
  static set instance(OneGatePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
