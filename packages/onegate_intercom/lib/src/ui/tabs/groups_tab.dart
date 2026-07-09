import 'package:flutter/material.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';

import '../../i18n/intercom_i18n.dart';
import '../../intercom_config.dart';
import '../../models/room.dart';
import '../../services/room_service.dart';
import '../chat_screen.dart';

class GroupsTab extends StatelessWidget {
  const GroupsTab({
    super.key,
    required this.host,
    required this.ctx,
    required this.config,
  });

  final FeatureHost host;
  final SocietyContext ctx;
  final IntercomConfig config;

  @override
  Widget build(BuildContext context) {
    if (!config.enableGroups) {
      return Center(
        child: Text(
          intercomTr(
            context,
            'chatCall_groupsDisabled',
            fallback: 'Groups disabled',
          ),
        ),
      );
    }

    return _RoomsList(host: host, ctx: ctx);
  }
}

class _RoomsList extends StatefulWidget {
  const _RoomsList({required this.host, required this.ctx});

  final FeatureHost host;
  final SocietyContext ctx;

  @override
  State<_RoomsList> createState() => _RoomsListState();
}

class _RoomsListState extends State<_RoomsList> {
  bool _loading = true;
  String? _error;
  List<Room> _rooms = const [];

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
      final svc = RoomService.fromHost(widget.host);
      final rooms = await svc.getRooms(companyId: widget.ctx.societyId);
      if (!mounted) return;
      setState(() => _rooms = rooms);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(Room r) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(host: widget.host, ctx: widget.ctx, room: r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              intercomTr(
                context,
                'chatCall_failedToLoadGroupsWithError',
                fallback: 'Failed to load groups: $_error',
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

    if (_rooms.isEmpty) {
      return Center(
        child: Text(
          intercomTr(context, 'chatCall_noGroups', fallback: 'No groups'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _rooms.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final r = _rooms[index];
          return ListTile(
            title: Text(r.name),
            subtitle: Text(r.description ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(r),
          );
        },
      ),
    );
  }
}
