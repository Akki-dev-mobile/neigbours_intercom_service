import 'dart:io';
import 'package:flutter/foundation.dart';

class SSLHelper {
  static void initialize() {
    HttpOverrides.global = MyHttpOverrides();
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Accept all certificates for stgsso.cubeone.in
        if (host.contains('stgsso.cubeone.in')) {
          debugPrint('Accepting certificate for $host');
          return true;
        }
        return false;
      };
  }
}
