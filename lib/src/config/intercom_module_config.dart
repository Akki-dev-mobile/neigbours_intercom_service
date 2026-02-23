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
  final IntercomEndpoints endpoints;
  final http.Client? httpClient;

  const IntercomModuleConfig({
    required this.authPort,
    required this.contextPort,
    required this.endpoints,
    this.httpClient,
  });
}

class IntercomModule {
  static IntercomModuleConfig? _config;

  static void configure(IntercomModuleConfig config) {
    _config = config;
  }

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

