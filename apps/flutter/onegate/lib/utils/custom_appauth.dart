import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter_onegate/utils/ssl_helper.dart';

class CustomAppAuth {
  static Future<void> configureAppAuth() async {
    try {
      // Initialize SSL helper for certificate handling
      SSLHelper.initialize();

      if (kDebugMode) {
        log('✅ AppAuth configured for debug mode with SSL bypass');
      } else {
        log('✅ AppAuth configured for production mode');
      }
    } catch (e) {
      log('⚠️ Error configuring AppAuth: $e');
      // Don't throw error, just log it
    }
  }
}
