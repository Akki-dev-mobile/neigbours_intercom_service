import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter_onegate/utils/ssl_helper.dart';

class CustomAppAuth {
  static Future<void> initialize() async {
    try {
      // Initialize SSL helper
      SSLHelper.initialize();

      if (kDebugMode) {
        log('✅ CustomAppAuth initialized for debug mode with SSL bypass');
      } else {
        log('✅ CustomAppAuth initialized for production mode');
      }
    } catch (e) {
      log('⚠️ Error initializing CustomAppAuth: $e');
      // Don't throw error, just log it
    }
  }
}
