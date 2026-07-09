import 'package:flutter/material.dart';
import '../../../../src/config/chat_call_i18n.dart';

import '../models/intercom_contact.dart';
import '../models/room_model.dart';
import '../services/chat_service.dart';
import '../services/intercom_service.dart';
import '../../../../core/models/api_response.dart';
import '../../../../core/widgets/onegate_global_loader.dart';

enum ForwardTargetType { group, member }

class ForwardSelection {
  final ForwardTargetType type;
  final Room? room;
  final IntercomContact? contact;

  const ForwardSelection.group(this.room)
    : type = ForwardTargetType.group,
      contact = null;

  const ForwardSelection.member(this.contact)
    : type = ForwardTargetType.member,
      room = null;
}

class ForwardTargetsData {
  final List<Room> groups;
  final List<IntercomContact> contacts;

  const ForwardTargetsData({required this.groups, required this.contacts});
}

/// Reusable bottom sheet that mirrors the Intercom tabs to list
/// all groups and all enabled members for forwarding.
class ForwardToBottomSheet extends StatefulWidget {
  final int companyId;
  final ChatService chatService;
  final IntercomService intercomService;

  const ForwardToBottomSheet({
    super.key,
    required this.companyId,
    required this.chatService,
    required this.intercomService,
  });

  static Future<ForwardSelection?> show({
    required BuildContext context,
    required int companyId,
    required ChatService chatService,
    required IntercomService intercomService,
  }) {
    return showModalBottomSheet<ForwardSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.88,
        child: ForwardToBottomSheet(
          companyId: companyId,
          chatService: chatService,
          intercomService: intercomService,
        ),
      ),
    );
  }

  @override
  State<ForwardToBottomSheet> createState() => _ForwardToBottomSheetState();
}

class _ForwardToBottomSheetState extends State<ForwardToBottomSheet> {
  static const Color _onegateRed = Color(0xFFF44336);

  bool _isLoading = true;
  String? _error;
  ForwardTargetsData? _data;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final residentsFuture = widget.intercomService.getResidents(
        companyId: widget.companyId,
      );
      final committeeFuture = widget.intercomService.getCommitteeMembers(
        companyId: widget.companyId,
      );
      final gatekeepersFuture = widget.intercomService.getGatekeepers(
        companyId: widget.companyId,
      );
      final officeFuture = widget.intercomService.getSocietyOfficeContacts(
        companyId: widget.companyId,
      );
      final lobbiesFuture = widget.intercomService.getLobbies(
        companyId: widget.companyId,
      );

      final groupsFuture = widget.chatService.fetchRooms(
        companyId: widget.companyId,
        chatType: 'group',
      );

      final results = await Future.wait([
        residentsFuture,
        committeeFuture,
        gatekeepersFuture,
        officeFuture,
        lobbiesFuture,
        groupsFuture,
      ]);

      final residents = results[0] as List<IntercomContact>;
      final committee = results[1] as List<IntercomContact>;
      final gatekeepers = results[2] as List<IntercomContact>;
      final office = results[3] as List<IntercomContact>;
      final lobbies = results[4] as List<IntercomContact>;
      final groupsResponse = results[5];

      final groups = groupsResponse is ApiResponse<List<Room>>
          ? (groupsResponse.data ?? <Room>[])
          : <Room>[];

      final Map<String, IntercomContact> contactMap = {};
      for (final contact in [
        ...residents,
        ...committee,
        ...gatekeepers,
        ...office,
        ...lobbies,
      ]) {
        if (contact.hasUserId) {
          contactMap.putIfAbsent(contact.id, () => contact);
        }
      }

      if (!mounted) return;
      setState(() {
        _data = ForwardTargetsData(
          groups: groups,
          contacts: contactMap.values.toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            ),
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = chatCallTr(
          context,
          'chatCall_failedToLoadContacts',
          fallback: 'Failed to load contacts. Please try again.',
        );
        _isLoading = false;
      });
    }
  }

  List<Room> get _filteredGroups {
    if (_data == null) return [];
    if (_query.isEmpty) return _data!.groups;
    final q = _query.toLowerCase();
    return _data!.groups
        .where(
          (room) =>
              room.name.toLowerCase().contains(q) ||
              (room.description ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  List<IntercomContact> get _filteredContacts {
    if (_data == null) return [];
    if (_query.isEmpty) return _data!.contacts;
    final q = _query.toLowerCase();
    return _data!.contacts
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              (c.unit ?? '').toLowerCase().contains(q) ||
              c.typeLabel.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
              child: Row(
                children: [
                  Text(
                    chatCallTr(
                      context,
                      'chatCall_forwardTo',
                      fallback: 'Forward to',
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff212427),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: _onegateRed),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: chatCallTr(
                    context,
                    'chatCall_searchGroupsOrMembers',
                    fallback: 'Search groups or members',
                  ),
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: const Icon(Icons.search, color: _onegateRed),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: _onegateRed,
                      width: 1.5,
                    ),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _query = value.trim();
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: OneGateGlobalLoader(
                        title: chatCallTr(
                          context,
                          'chatCall_loadingChats',
                          fallback: 'Loading Chats',
                        ),
                        subtitle: chatCallTr(
                          context,
                          'chatCall_fetchingGroupsAndMembers',
                          fallback: 'Fetching groups and members...',
                        ),
                      ),
                    )
                  : _error != null
                  ? _buildErrorState()
                  : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _onegateRed.withOpacity(0.1),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 28,
              color: _onegateRed,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _loadTargets,
            style: TextButton.styleFrom(foregroundColor: _onegateRed),
            child: Text(
              chatCallTr(context, 'chatCall_retry', fallback: 'Retry'),
            ),
          ),
        ],
      ),
    );
  }

  String _roomInitials(Room room) {
    if (room.name.trim().isEmpty) return 'G';
    return room.name.trim()[0].toUpperCase();
  }

  Widget _buildResults() {
    final groups = _filteredGroups;
    final contacts = _filteredContacts;

    if (groups.isEmpty && contacts.isEmpty) {
      return Center(
        child: Text(
          chatCallTr(
            context,
            'chatCall_noGroupsOrMembersFound',
            fallback: 'No groups or members found.',
          ),
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (groups.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              chatCallTr(
                context,
                'chatCall_groupsCount',
                fallback: 'Groups (${groups.length})',
                params: {'count': '${groups.length}'},
              ),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          ...groups.map((room) => _buildGroupRow(room)),
          const SizedBox(height: 16),
        ],
        if (contacts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              chatCallTr(
                context,
                'chatCall_membersCountLabel',
                fallback: 'Members (${contacts.length})',
                params: {'count': '${contacts.length}'},
              ),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          ...contacts.map((contact) => _buildMemberRow(contact)),
        ],
      ],
    );
  }

  Widget _buildGroupRow(Room room) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => Navigator.pop(context, ForwardSelection.group(room)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildGroupAvatar(room),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Color(0xff212427),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${room.membersCount ?? 0} member${(room.membersCount ?? 0) == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupAvatar(Room room) {
    final initials = _roomInitials(room);
    final photoUrl = room.photoUrl;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: _onegateRed.withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: photoUrl != null && photoUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Image.network(
                photoUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _groupAvatarFallback(initials),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _groupAvatarFallback(initials);
                },
              ),
            )
          : _groupAvatarFallback(initials),
    );
  }

  Widget _groupAvatarFallback(String initials) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: _onegateRed,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildMemberRow(IntercomContact contact) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => Navigator.pop(context, ForwardSelection.member(contact)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildMemberAvatar(contact),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Color(0xff212427),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.typeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(IntercomContact contact) {
    final photoUrl = contact.photoUrl;
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        color: Color(0xffffebee),
        shape: BoxShape.circle,
      ),
      child: photoUrl != null && photoUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Image.network(
                photoUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _memberAvatarFallback(contact.initials),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _memberAvatarFallback(contact.initials);
                },
              ),
            )
          : _memberAvatarFallback(contact.initials),
    );
  }

  Widget _memberAvatarFallback(String initials) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: _onegateRed,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}
