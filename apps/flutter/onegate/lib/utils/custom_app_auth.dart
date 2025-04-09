import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onegate/utils/ssl_helper.dart';

class CustomAppAuth {
  static const MethodChannel _channel = MethodChannel('plugins.flutter.io/flutter_appauth');

  static Future<void> initialize() async {
    try {
      // Initialize SSL helper
      SSLHelper.initialize();
      
      // Set up platform-specific configurations
      if (Platform.isAndroid) {
        await _channel.invokeMethod('configurePlatformSpecifics', {
          'allowInsecureConnections': true,
        });
      }
    } catch (e) {
      debugPrint('Error initializing CustomAppAuth: $e');
    }
  }
}
