import 'package:flutter/material.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';

import '../guard_intercom_config.dart';
import '../i18n/guard_intercom_i18n.dart';

class IntercomHomeScreen extends StatelessWidget {
  const IntercomHomeScreen({
    super.key,
    required this.host,
    required this.ctx,
    required this.config,
  });

  final FeatureHost host;
  final SocietyContext ctx;
  final GuardIntercomConfig config;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          guardIntercomTr(
            context,
            'chatCall_guardIntercomTitle',
            fallback: 'Guard Intercom',
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              guardIntercomTr(
                context,
                'chatCall_societyIdLabel',
                fallback: 'societyId: ${ctx.societyId}',
                params: {'value': ctx.societyId},
              ),
            ),
            Text(
              guardIntercomTr(
                context,
                'chatCall_flatIdLabel',
                fallback: 'flatId: ${ctx.flatId ?? '-'}',
                params: {'value': ctx.flatId ?? '-'},
              ),
            ),
            Text(
              guardIntercomTr(
                context,
                'chatCall_roleLabel',
                fallback: 'role: ${ctx.role}',
                params: {'value': ctx.role.toString()},
              ),
            ),
            const SizedBox(height: 12),
            Text(
              guardIntercomTr(
                context,
                'chatCall_callsEnabledLabel',
                fallback: 'callsEnabled: ${config.callsEnabled}',
                params: {'value': '${config.callsEnabled}'},
              ),
            ),
            Text(
              guardIntercomTr(
                context,
                'chatCall_videoEnabledLabel',
                fallback: 'videoEnabled: ${config.videoEnabled}',
                params: {'value': '${config.videoEnabled}'},
              ),
            ),
            const SizedBox(height: 24),
            Text(
              guardIntercomTr(
                context,
                'chatCall_guardScaffoldReady',
                fallback:
                    'Scaffold package ready. Next: migrate existing intercom chat/call UI into this package.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
