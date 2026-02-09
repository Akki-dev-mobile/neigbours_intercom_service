import 'package:flutter/material.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';

import '../neighbours_config.dart';

class NeighboursHomeScreen extends StatelessWidget {
  const NeighboursHomeScreen({
    super.key,
    required this.host,
    required this.ctx,
    required this.config,
  });

  final FeatureHost host;
  final SocietyContext ctx;
  final NeighboursConfig config;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neighbours')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('societyId: ${ctx.societyId}'),
            Text('flatId: ${ctx.flatId ?? '-'}'),
            Text('role: ${ctx.role}'),
            const SizedBox(height: 12),
            Text('postingEnabled: ${config.postingEnabled}'),
            Text('commentsEnabled: ${config.commentsEnabled}'),
            Text('mediaEnabled: ${config.mediaEnabled}'),
            const SizedBox(height: 24),
            const Text(
              'Scaffold package ready. Next: migrate existing neighbour/resident/group UI into this package.',
            ),
          ],
        ),
      ),
    );
  }
}

