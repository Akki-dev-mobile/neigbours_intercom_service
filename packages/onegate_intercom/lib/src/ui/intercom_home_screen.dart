import 'package:flutter/material.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';

import '../intercom_config.dart';
import 'tabs/committee_tab.dart';
import 'tabs/groups_tab.dart';
import 'tabs/residents_tab.dart';

class IntercomHomeScreen extends StatefulWidget {
  const IntercomHomeScreen({
    super.key,
    required this.host,
    required this.ctx,
    required this.config,
  });

  final FeatureHost host;
  final SocietyContext ctx;
  final IntercomConfig config;

  @override
  State<IntercomHomeScreen> createState() => _IntercomHomeScreenState();
}

class _IntercomHomeScreenState extends State<IntercomHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intercom'),
        bottom: TabBar(
          controller: _controller,
          tabs: const [
            Tab(text: 'Residents'),
            Tab(text: 'Committee'),
            Tab(text: 'Groups'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: [
          ResidentsTab(host: widget.host, ctx: widget.ctx, config: widget.config),
          CommitteeTab(host: widget.host, ctx: widget.ctx, config: widget.config),
          GroupsTab(host: widget.host, ctx: widget.ctx, config: widget.config),
        ],
      ),
    );
  }
}
