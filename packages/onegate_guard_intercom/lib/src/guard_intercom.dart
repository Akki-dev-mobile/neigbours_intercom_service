import 'package:flutter/material.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';
import 'package:onegate_intercom/onegate_intercom.dart' as intercom;

import 'guard_intercom_config.dart';

/// Public entry point API for host apps.
Future<void> startIntercom(
  BuildContext context, {
  required FeatureHost host,
  SocietyContext? ctx,
  GuardIntercomConfig? configOverride,
}) async {
  final effectiveCtx = ctx ?? host.currentContext();
  final baseConfig = host.featureConfig();
  final enabled = baseConfig.guardIntercomEnabled;

  if (!enabled) {
    host.log('Guard Intercom disabled by FeatureConfig');
    return;
  }

  final roleAllowed = (configOverride?.allowedRoles == null)
      ? true
      : configOverride!.allowedRoles!.contains(effectiveCtx.role);

  if (!roleAllowed) {
    host.log('Guard Intercom blocked for role ${effectiveCtx.role}');
    return;
  }

  // Start full Intercom (Neighbours-style) experience.
  // If you need the old guard member list screen, wire it behind a flag.
  await intercom.openIntercom(
    context,
    host: host,
    ctx: effectiveCtx,
    configOverride: const intercom.IntercomConfig(),
  );
}
