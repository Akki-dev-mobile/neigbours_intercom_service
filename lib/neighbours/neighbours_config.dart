import 'package:flutter/foundation.dart';

import 'package:neigbours_intercom_service/core/contracts/neighbour_role.dart';

/// Feature toggles for the Neighbours hub (groups / residents / committee).
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

  /// When non-null and non-empty, only these roles may open the Neighbours hub.
  final Set<NeighbourRole>? allowedRoles;
}
