import 'package:flutter/foundation.dart';

import 'package:onegate_feature_core/onegate_feature_core.dart';

@immutable
class GuardIntercomConfig {
  const GuardIntercomConfig({
    this.callsEnabled = true,
    this.videoEnabled = false,
    this.fromNumber,
    this.allowedRoles,
  });

  final bool callsEnabled;
  final bool videoEnabled;

  /// Exotel caller number used for intercom calls & call logs.
  ///
  /// If null, the host app should provide a default via [FeatureConfig.flags]
  /// or the feature will use a safe fallback.
  final String? fromNumber;
  final Set<UserRole>? allowedRoles;
}
