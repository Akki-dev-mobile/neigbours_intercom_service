import 'package:flutter/material.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';

import '../../i18n/intercom_i18n.dart';
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
      final contacts =
          await svc.fetchCommittee(companyId: widget.ctx.societyId);
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
        SnackBar(
          content: Text(
            intercomTr(
              context,
              'chatCall_callFailedWithError',
              fallback: 'Call failed: $e',
              params: {'error': _localizedCallError(context, e)},
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.config.enableCommittee) {
      return Center(
        child: Text(
          intercomTr(
            context,
            'chatCall_committeeDisabled',
            fallback: 'Committee disabled',
          ),
        ),
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              intercomTr(
                context,
                'chatCall_failedToLoadWithError',
                fallback: 'Failed to load: $_error',
                params: {'error': _error ?? ''},
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              child: Text(
                intercomTr(context, 'chatCall_retry', fallback: 'Retry'),
              ),
            ),
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

String _localizedCallError(BuildContext context, Object error) {
  final raw = error.toString();
  if (raw.contains('Microphone permission required')) {
    return intercomTr(
      context,
      'chatCall_microphonePermissionRequired',
      fallback: 'Microphone permission required',
    );
  }
  if (raw.contains('Camera permission required')) {
    return intercomTr(
      context,
      'chatCall_cameraPermissionRequired',
      fallback: 'Camera permission required',
    );
  }
  if (raw.contains('Unexpected call response')) {
    return intercomTr(
      context,
      'chatCall_unexpectedCallResponse',
      fallback: 'Unexpected call response',
    );
  }
  if (raw.contains('Missing call data')) {
    return intercomTr(
      context,
      'chatCall_missingCallData',
      fallback: 'Missing call data',
    );
  }
  if (raw.contains('Missing meeting_id')) {
    return intercomTr(
      context,
      'chatCall_missingMeetingId',
      fallback: 'Missing meeting ID',
    );
  }
  return raw.replaceFirst('Exception: ', '');
}
