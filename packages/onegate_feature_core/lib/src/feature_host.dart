import 'package:flutter/foundation.dart';

import 'feature_config.dart';
import 'models/auth_session.dart';
import 'models/society_context.dart';

/// Boundary between a host app and a plug-and-play feature package.
///
/// Features must depend only on this contract (not on host app singletons).
@immutable
abstract class FeatureHost {
  const FeatureHost();

  /// Base URL for Kong (e.g. https://apigw.example.com).
  Uri kongBaseUri();

  /// Current in-app context (selected society/flat and role).
  SocietyContext currentContext();

  /// Feature flags & per-app behavior toggles (local and/or remote).
  FeatureConfig featureConfig();

  /// Access token used for backend calls. Refresh flows (if needed) are owned by the host.
  Future<AuthSession> authSession();

  /// Optional event tracking hook.
  void track(String name, {Map<String, Object?> props = const {}}) {}

  /// Optional diagnostics logging hook.
  void log(String message, {Object? error, StackTrace? stackTrace}) {}
}
