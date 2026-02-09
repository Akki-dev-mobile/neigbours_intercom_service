import 'package:flutter/foundation.dart';

import 'package:onegate_feature_core/onegate_feature_core.dart';

@immutable
class NeighboursConfig {
  const NeighboursConfig({
    this.postingEnabled = true,
    this.commentsEnabled = true,
    this.mediaEnabled = true,
    this.allowedRoles,
  });

  final bool postingEnabled;
  final bool commentsEnabled;
  final bool mediaEnabled;
  final Set<UserRole>? allowedRoles;
}
