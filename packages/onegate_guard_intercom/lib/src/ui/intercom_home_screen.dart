import 'package:flutter/material.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';

import '../guard_intercom_config.dart';

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
      appBar: AppBar(title: const Text('Guard Intercom')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('societyId: ${ctx.societyId}'),
            Text('flatId: ${ctx.flatId ?? '-'}'),
            Text('role: ${ctx.role}'),
            const SizedBox(height: 12),
            Text('callsEnabled: ${config.callsEnabled}'),
            Text('videoEnabled: ${config.videoEnabled}'),
            const SizedBox(height: 24),
            const Text(
              'Scaffold package ready. Next: migrate existing intercom chat/call UI into this package.',
            ),
          ],
        ),
      ),
    );
  }
}

