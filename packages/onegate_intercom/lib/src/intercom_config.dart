import 'package:flutter/foundation.dart';

import 'package:onegate_feature_core/onegate_feature_core.dart';

@immutable
class IntercomConfig {
  const IntercomConfig({
    this.allowedRoles,
    this.enableCalls = true,
    this.enableGroups = true,
    this.enableResidents = true,
    this.enableCommittee = true,
  });

  final Set<UserRole>? allowedRoles;
  final bool enableCalls;
  final bool enableGroups;
  final bool enableResidents;
  final bool enableCommittee;
}

