import 'package:flutter/material.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';

import 'intercom_config.dart';
import 'ui/intercom_home_screen.dart';

/// Public entry point API for host apps.
///
/// Required flags in [FeatureConfig.flags] (strings):
/// - `onegate.societyBaseUrl` (example: https://societybackend.cubeone.in/api)
/// - `onegate.chatApiBaseUrl` (example: http://13.201.27.102:7071/api/v1)
/// - `onegate.callApiBaseUrl` (call service base url)
/// - `onegate.jitsiServerUrl` (example: https://collab.cubeone.in)
Future<void> openIntercom(
  BuildContext context, {
  required FeatureHost host,
  SocietyContext? ctx,
  IntercomConfig? configOverride,
}) async {
  final effectiveCtx = ctx ?? host.currentContext();
  final baseConfig = host.featureConfig();
  final enabled = baseConfig.guardIntercomEnabled || baseConfig.neighboursEnabled;

  if (!enabled) {
    host.log('Intercom disabled by FeatureConfig');
    return;
  }

  final roleAllowed = (configOverride?.allowedRoles == null)
      ? true
      : configOverride!.allowedRoles!.contains(effectiveCtx.role);

  if (!roleAllowed) {
    host.log('Intercom blocked for role ${effectiveCtx.role}');
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => IntercomHomeScreen(
        host: host,
        ctx: effectiveCtx,
        config: configOverride ?? const IntercomConfig(),
      ),
    ),
  );
}

