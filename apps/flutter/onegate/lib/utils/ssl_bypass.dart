import 'dart:io';
import 'dart:developer';

// Custom HTTP overrides to accept all certificates for specific domains
class SSLBypassHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // List of domains to bypass SSL certificate validation
        final trustedDomains = [
          'stgsso.cubeone.in',
          'gateapi.cubeone.in',
          'cubeone.in' // Trust all subdomains of cubeone.in
        ];

        // Check if the host is in our trusted domains list
        for (final domain in trustedDomains) {
          if (host.contains(domain)) {
            log('Accepting certificate for $host');
            return true;
          }
        }

        return false;
      };
  }
}

// Initialize SSL bypass for Android
void initializeSSLBypass() {
  if (Platform.isAndroid) {
    HttpOverrides.global = SSLBypassHttpOverrides();
    log('SSL certificate validation bypass initialized for Android');
  }
}
