import 'package:flutter/material.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';

import '../../i18n/intercom_i18n.dart';
import '../../intercom_config.dart';
import '../../services/directory_service.dart';
import '../../services/jitsi_call_manager.dart';

class ResidentsTab extends StatefulWidget {
  const ResidentsTab({
    super.key,
    required this.host,
    required this.ctx,
    required this.config,
  });

  final FeatureHost host;
  final SocietyContext ctx;
  final IntercomConfig config;

  @override
  State<ResidentsTab> createState() => _ResidentsTabState();
}

class _ResidentsTabState extends State<ResidentsTab> {
  bool _loading = true;
  String? _error;
  List<DirectoryContact> _contacts = const [];
  String _searchQuery = '';
  _ResidentScope _scope = _ResidentScope.cyberOne;

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
          await svc.fetchResidents(companyId: widget.ctx.societyId);
      if (!mounted) return;
      setState(() => _contacts = contacts);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DirectoryContact> get _visibleContacts {
    if (_searchQuery.trim().isEmpty) return _contacts;
    final q = _searchQuery.trim().toLowerCase();
    return _contacts.where((c) {
      final name = c.name.toLowerCase();
      final phone = c.phone?.toLowerCase() ?? '';
      return name.contains(q) || phone.contains(q);
    }).toList();
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
    if (!widget.config.enableResidents) {
      return Center(
        child: Text(
          intercomTr(
            context,
            'chatCall_residentsDisabled',
            fallback: 'Residents disabled',
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
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

    final visible = _visibleContacts;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _ScopeChip(
                  label: intercomTr(
                    context,
                    'chatCall_cyberOneScope',
                    fallback: 'CyberOne',
                  ),
                  selected: _scope == _ResidentScope.cyberOne,
                  onSelected: (_) {
                    setState(() => _scope = _ResidentScope.cyberOne);
                  },
                ),
                const SizedBox(width: 8),
                _ScopeChip(
                  label: intercomTr(
                    context,
                    'chatCall_flatScope',
                    fallback: 'Flat',
                  ),
                  selected: _scope == _ResidentScope.flat,
                  onSelected: (_) {
                    setState(() => _scope = _ResidentScope.flat);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ResidentsSearchField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  _scope == _ResidentScope.cyberOne
                      ? intercomTr(
                          context,
                          'chatCall_cyberOneScope',
                          fallback: 'CyberOne',
                        )
                      : intercomTr(
                          context,
                          'chatCall_flatScope',
                          fallback: 'Flat',
                        ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xffffebee),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    intercomTr(
                      context,
                      'chatCall_residentsCount',
                      fallback: '${visible.length} residents',
                      params: {'count': '${visible.length}'},
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xffc62828),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final c = visible[index];
                  return _ResidentCard(
                    contact: c,
                    showCallAction: widget.config.enableCalls,
                    onCallTap: () => _call(c),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ResidentScope { cyberOne, flat }

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.grey[800],
        fontWeight: FontWeight.w600,
      ),
      selectedColor: const Color(0xffc62828),
      backgroundColor: Colors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? Colors.transparent : Colors.grey[300]!,
          width: 1,
        ),
      ),
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

class _ResidentsSearchField extends StatelessWidget {
  const _ResidentsSearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: intercomTr(
                  context,
                  'chatCall_searchResidentsHint',
                  fallback: 'Search residents...',
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xffffebee),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.mic, color: Color(0xffc62828)),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _ResidentCard extends StatelessWidget {
  const _ResidentCard({
    required this.contact,
    required this.showCallAction,
    required this.onCallTap,
  });

  final DirectoryContact contact;
  final bool showCallAction;
  final VoidCallback onCallTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xffffebee),
                      child: Text(
                        contact.initial,
                        style: const TextStyle(
                          color: Color(0xffc62828),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.phone ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        intercomTr(
                          context,
                          'chatCall_notOneappUser',
                          fallback: 'Not a oneapp user',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xffff8f00),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xffffa000),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          intercomTr(
                            context,
                            'chatCall_inviteComingSoon',
                            fallback: 'Invite action coming soon',
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: Text(
                    intercomTr(context, 'chatCall_invite', fallback: 'Invite'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text(
                    intercomTr(context, 'chatCall_chat', fallback: 'Chat'),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue[600],
                  ),
                ),
                const Spacer(),
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.grey[300],
                ),
                if (showCallAction && contact.phone != null) ...[
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.call),
                    color: const Color(0xff4caf50),
                    onPressed: onCallTap,
                  ),
                ] else ...[
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.call),
                    color: Colors.grey[400],
                    onPressed: null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
