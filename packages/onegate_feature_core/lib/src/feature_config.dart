import 'package:flutter/foundation.dart';

import 'models/user_role.dart';

@immutable
class FeatureConfig {
  const FeatureConfig({
    required this.neighboursEnabled,
    required this.guardIntercomEnabled,
    this.flags = const {},
  });

  final bool neighboursEnabled;
  final bool guardIntercomEnabled;

  /// App-specific booleans/strings/numbers for UI and behavior tweaks.
  /// Features may define typed config classes and read from here as a fallback.
  final Map<String, Object?> flags;

  bool enabledForRole({
    required bool enabled,
    required UserRole role,
    Set<UserRole>? allowedRoles,
  }) {
    if (!enabled) return false;
    if (allowedRoles == null) return true;
    return allowedRoles.contains(role);
  }
}
