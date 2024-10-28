import 'package:flutter_test/flutter_test.dart';
import 'package:one_gate/one_gate.dart';
import 'package:one_gate/one_gate_platform_interface.dart';
import 'package:one_gate/one_gate_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockOneGatePlatform
    with MockPlatformInterfaceMixin
    implements OneGatePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final OneGatePlatform initialPlatform = OneGatePlatform.instance;

  test('$MethodChannelOneGate is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelOneGate>());
  });

  test('getPlatformVersion', () async {
    OneGate oneGatePlugin = OneGate();
    MockOneGatePlatform fakePlatform = MockOneGatePlatform();
    OneGatePlatform.instance = fakePlatform;

    expect(await oneGatePlugin.getPlatformVersion(), '42');
  });
}
