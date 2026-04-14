import 'package:flutter/material.dart';

import 'package:neigbours_intercom_service/core/contracts/neighbour_role.dart';
import 'package:neigbours_intercom_service/core/utils/role_gate.dart';
import 'package:neigbours_intercom_service/intercom/intercom_screen.dart';
import 'package:neigbours_intercom_service/intercom/guard_intercom_config.dart';
import 'package:neigbours_intercom_service/neighbours/neighbours_config.dart';
import 'package:neigbours_intercom_service/src/config/intercom_module_config.dart';

import 'neighbours_screen.dart';

void _ensureConfigured() {
  if (!IntercomModule.isConfigured) {
    throw StateError(
      'Call IntercomModule.configure(...) before using Neighbours / Intercom.',
    );
  }
}

/// Pushes the Neighbours hub ([NeighbourScreen]). Requires [IntercomModule.configure].
void pushNeighboursScreen(
  BuildContext context, {
  NeighboursConfig config = const NeighboursConfig(),
}) {
  _ensureConfigured();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NeighbourScreen(config: config),
    ),
  );
}

/// Pushes [IntercomScreen]. Requires [IntercomModule.configure].
void pushIntercomScreen(
  BuildContext context, {
  bool showGatekeeperTab = true,
  bool fromOneGateCard = false,
  bool fromNeighborsCard = false,
  GuardIntercomConfig guardConfig = const GuardIntercomConfig(),
}) {
  _ensureConfigured();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => IntercomScreen(
        showGatekeeperTab: showGatekeeperTab,
        fromOneGateCard: fromOneGateCard,
        fromNeighborsCard: fromNeighborsCard,
        guardConfig: guardConfig,
      ),
    ),
  );
}

/// Mirrors monorepo [openNeighbours]: respects feature flag + role gate, then navigates.
///
/// Host supplies [neighboursFeatureEnabled] (e.g. from remote flags). Returns `false` if blocked.
bool tryOpenNeighbours(
  BuildContext context, {
  required bool neighboursFeatureEnabled,
  NeighbourRole? currentRole,
  NeighboursConfig config = const NeighboursConfig(),
  void Function(String reason)? onBlocked,
}) {
  _ensureConfigured();
  if (!neighboursFeatureEnabled) {
    onBlocked?.call('Neighbours disabled');
    return false;
  }
  if (!isNeighbourRoleAllowed(currentRole, config.allowedRoles)) {
    onBlocked?.call('Neighbours blocked for current role');
    return false;
  }
  pushNeighboursScreen(context, config: config);
  return true;
}

/// Mirrors monorepo [startIntercom]: respects feature flag + role gate, then navigates.
///
/// [intercomFeatureEnabled] replaces `FeatureConfig.guardIntercomEnabled`.
bool tryOpenIntercom(
  BuildContext context, {
  required bool intercomFeatureEnabled,
  NeighbourRole? currentRole,
  GuardIntercomConfig config = const GuardIntercomConfig(),
  bool showGatekeeperTab = true,
  bool fromOneGateCard = false,
  bool fromNeighborsCard = false,
  void Function(String reason)? onBlocked,
}) {
  _ensureConfigured();
  if (!intercomFeatureEnabled) {
    onBlocked?.call('Guard Intercom disabled');
    return false;
  }
  if (!isNeighbourRoleAllowed(currentRole, config.allowedRoles)) {
    onBlocked?.call('Guard Intercom blocked for current role');
    return false;
  }
  pushIntercomScreen(
    context,
    showGatekeeperTab: showGatekeeperTab,
    fromOneGateCard: fromOneGateCard,
    fromNeighborsCard: fromNeighborsCard,
    guardConfig: config,
  );
  return true;
}
