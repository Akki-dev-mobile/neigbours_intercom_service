import 'package:flutter/material.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';

import '../../intercom_config.dart';
import '../../services/directory_service.dart';
import '../../services/jitsi_call_manager.dart';

class CommitteeTab extends StatefulWidget {
  const CommitteeTab({
    super.key,
    required this.host,
    required this.ctx,
    required this.config,
  });

  final FeatureHost host;
  final SocietyContext ctx;
  final IntercomConfig config;

  @override
  State<CommitteeTab> createState() => _CommitteeTabState();
}

class _CommitteeTabState extends State<CommitteeTab> {
  bool _loading = true;
  String? _error;
  List<DirectoryContact> _contacts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final svc = DirectoryService.fromHost(widget.host);
      final contacts = await svc.fetchCommittee(companyId: widget.ctx.societyId);
      if (!mounted) return;
      setState(() => _contacts = contacts);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _call(DirectoryContact c) async {
    if (!widget.config.enableCalls) return;
    final mgr = JitsiCallManager.fromHost(widget.host);
    try {
      await mgr.initiateVideoCall(
        toUserId: c.userId,
        toUserPhone: c.phone,
        toUserAvatarUrl: c.avatarUrl,
        displayName: widget.ctx.userId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Call failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.config.enableCommittee) {
      return const Center(child: Text('Committee disabled'));
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load: $_error'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _contacts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = _contacts[index];
        return ListTile(
          leading: CircleAvatar(child: Text(c.initial)),
          title: Text(c.name),
          subtitle: Text(c.phone ?? ''),
          trailing: widget.config.enableCalls
              ? IconButton(
                  icon: const Icon(Icons.video_call),
                  onPressed: () => _call(c),
                )
              : null,
        );
      },
    );
  }
}
