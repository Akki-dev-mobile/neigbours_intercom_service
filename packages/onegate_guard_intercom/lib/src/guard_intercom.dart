import 'package:flutter/material.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';

import 'guard_intercom_config.dart';
import 'ui/member_list_screen.dart';

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

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => GuardIntercomMemberListScreen(
        host: host,
        ctx: effectiveCtx,
        config: configOverride ?? const GuardIntercomConfig(),
      ),
    ),
  );
}
