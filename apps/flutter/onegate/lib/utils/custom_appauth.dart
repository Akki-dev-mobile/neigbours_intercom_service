import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

class CustomAppAuth {
  static const MethodChannel _channel = MethodChannel('plugins.flutter.io/flutter_appauth');

  static Future<void> configureAppAuth() async {
    try {
      // Configure the AppAuth plugin to allow insecure connections
      await _channel.invokeMethod('configure', {
        'allowInsecureConnections': true,
      });
      print('AppAuth configured to allow insecure connections');
    } catch (e) {
      print('Error configuring AppAuth: $e');
    }
  }
}
