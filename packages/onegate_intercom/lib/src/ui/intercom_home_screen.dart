import 'package:flutter/material.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';

import '../i18n/intercom_i18n.dart';
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
    final featureConfig = widget.host.featureConfig();
    final title = featureConfig.neighboursEnabled
        ? intercomTr(context, 'chatCall_neighborsTitle', fallback: 'Neighbors')
        : intercomTr(context, 'chatCall_intercomTitle', fallback: 'Intercom');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TabBar(
                controller: _controller,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: const Color(0xffc62828),
                unselectedLabelColor: Colors.grey[700],
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
                indicator: BoxDecoration(
                  color: const Color(0xffffebee),
                  borderRadius: BorderRadius.circular(12),
                ),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.people),
                    text: intercomTr(
                      context,
                      'chatCall_residentsTab',
                      fallback: 'Residents',
                    ),
                  ),
                  Tab(
                    icon: const Icon(Icons.groups),
                    text: intercomTr(
                      context,
                      'chatCall_committeeTab',
                      fallback: 'Committee',
                    ),
                  ),
                  Tab(
                    icon: const Icon(Icons.forum),
                    text: intercomTr(
                      context,
                      'chatCall_groupsTab',
                      fallback: 'Groups',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: [
          ResidentsTab(
              host: widget.host, ctx: widget.ctx, config: widget.config),
          CommitteeTab(
              host: widget.host, ctx: widget.ctx, config: widget.config),
          GroupsTab(host: widget.host, ctx: widget.ctx, config: widget.config),
        ],
      ),
    );
  }
}
