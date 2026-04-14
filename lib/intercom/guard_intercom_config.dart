import 'package:flutter/foundation.dart';

import 'package:neigbours_intercom_service/core/contracts/neighbour_role.dart';

/// Behaviour flags for Guard Intercom entry (aligned with monorepo `GuardIntercomConfig`).
@immutable
class GuardIntercomConfig {
  const GuardIntercomConfig({
    this.callsEnabled = true,
    this.videoEnabled = false,
    this.allowedRoles,
  });

  final bool callsEnabled;
  final bool videoEnabled;
  final Set<NeighbourRole>? allowedRoles;
}
