import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../ports/intercom_ports.dart';

/// Global configuration used by the extracted (legacy) module code.
///
/// This avoids having to thread dependencies through every widget/service
/// while still letting host apps inject API/auth/context.
@immutable
class IntercomModuleConfig {
  final IntercomAuthPort authPort;
  final IntercomContextPort contextPort;
  final IntercomUploadPort? uploadPort;
  final IntercomEndpoints endpoints;
  final http.Client? httpClient;
  final String? appPackageName;

  const IntercomModuleConfig({
    required this.authPort,
    required this.contextPort,
    this.uploadPort,
    required this.endpoints,
    this.httpClient,
    this.appPackageName,
  });

  factory IntercomModuleConfig.cubeOne({
    required IntercomAuthPort authPort,
    required IntercomContextPort contextPort,
    IntercomUploadPort? uploadPort,
    http.Client? httpClient,
    String? appPackageName,
  }) {
    return IntercomModuleConfig(
      authPort: authPort,
      contextPort: contextPort,
      uploadPort: uploadPort,
      endpoints: IntercomEndpoints.cubeOne,
      httpClient: httpClient,
      appPackageName: appPackageName,
    );
  }
}

class IntercomModule {
  static IntercomModuleConfig? _config;

  static void configure(IntercomModuleConfig config) {
    _config = config;
  }

  static bool get isConfigured => _config != null;

  static IntercomModuleConfig get config {
    final cfg = _config;
    if (cfg == null) {
      throw StateError(
        'IntercomModule is not configured. Call IntercomModule.configure(...) '
        'before using the module.',
      );
    }
    return cfg;
  }
}
