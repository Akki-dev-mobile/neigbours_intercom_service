import 'package:flutter/foundation.dart';

import 'package:onegate_feature_core/onegate_feature_core.dart';

@immutable
class GuardIntercomConfig {
  const GuardIntercomConfig({
    this.callsEnabled = true,
    this.videoEnabled = false,
    this.allowedRoles,
  });

  final bool callsEnabled;
  final bool videoEnabled;
  final Set<UserRole>? allowedRoles;
}
