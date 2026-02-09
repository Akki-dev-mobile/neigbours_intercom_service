import 'package:flutter/material.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';

import 'neighbours_config.dart';
import 'ui/neighbours_home_screen.dart';

/// Public entry point API for host apps.
///
/// The host provides [FeatureHost] for auth/context/config boundaries.
Future<void> openNeighbours(
  BuildContext context, {
  required FeatureHost host,
  SocietyContext? ctx,
  NeighboursConfig? configOverride,
}) async {
  final effectiveCtx = ctx ?? host.currentContext();
  final baseConfig = host.featureConfig();
  final enabled = baseConfig.neighboursEnabled;

  if (!enabled) {
    host.log('Neighbours disabled by FeatureConfig');
    return;
  }

  final roleAllowed = (configOverride?.allowedRoles == null)
      ? true
      : configOverride!.allowedRoles!.contains(effectiveCtx.role);

  if (!roleAllowed) {
    host.log('Neighbours blocked for role ${effectiveCtx.role}');
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => NeighboursHomeScreen(
        host: host,
        ctx: effectiveCtx,
        config: configOverride ?? const NeighboursConfig(),
      ),
    ),
  );
}

