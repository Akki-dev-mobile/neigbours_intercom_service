import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';

import '../api/guard_intercom_api.dart';
import '../guard_intercom_config.dart';

class GuardIntercomMemberListScreen extends StatefulWidget {
  const GuardIntercomMemberListScreen({
    super.key,
    required this.host,
    required this.ctx,
    required this.config,
  });

  final FeatureHost host;
  final SocietyContext ctx;
  final GuardIntercomConfig config;

  @override
  State<GuardIntercomMemberListScreen> createState() =>
      _GuardIntercomMemberListScreenState();
}

class _GuardIntercomMemberListScreenState
    extends State<GuardIntercomMemberListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<List<dynamic>> _filteredUnits = ValueNotifier([]);

  late final GuardIntercomApi _api = GuardIntercomApi.fromHost(widget.host);

  List<dynamic> _allUnits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterUnits);
    _initializeMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filteredUnits.dispose();
    super.dispose();
  }

  String _fromNumber() {
    final override = widget.config.fromNumber?.trim();
    if (override != null && override.isNotEmpty) return override;

    final flags = widget.host.featureConfig().flags;
    final from = flags['onegate.intercomFromNumber'];
    if (from is String && from.trim().isNotEmpty) return from.trim();

    return '918452060059';
  }

  Future<void> _initializeMembers() async {
    setState(() => _isLoading = true);
    try {
      final members = await _api.fetchMembers(companyId: widget.ctx.societyId);
      setState(() {
        _allUnits = members;
        _filteredUnits.value = members;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load members: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterUnits() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.length >= 3) {
      _filteredUnits.value = _allUnits.where((unit) {
        final u = (unit is Map) ? unit : const {};
        final flat = (u['unit_flat_number']?.toString() ?? '').toLowerCase();
        final building = (u['soc_building_name']?.toString() ?? '').toLowerCase();
        final members = u['member_details'] ?? const [];

        final matchInUnit = flat.contains(query) || building.contains(query);
        final matchInMembers = (members is List) && members.any((m) {
          if (m is! Map) return false;
          final name =
              '${m['member_first_name'] ?? ''} ${m['member_last_name'] ?? ''}'
                  .toLowerCase();
          return name.contains(query);
        });

        return matchInUnit || matchInMembers;
      }).toList();
    } else {
      _filteredUnits.value = _allUnits;
    }
  }

  Future<void> _openCallHistory() async {
    final fromNumber = _fromNumber();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuardIntercomCallHistoryScreen(
          host: widget.host,
          fromNumber: fromNumber,
          callsEnabled: widget.config.callsEnabled,
          onCallBack: (toNumber, memberName) =>
              _callMember(toNumber, memberName: memberName),
        ),
      ),
    );
  }

  Future<void> _callMember(String mobile, {required String memberName}) async {
    if (!widget.config.callsEnabled) return;

    try {
      await _api.initiateCall(
        fromNumber: _fromNumber(),
        toNumber: mobile,
        memberName: memberName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Will get a call soon')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initiating call: $e')),
      );
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name or flat',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: const Icon(Icons.search, color: Colors.black),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _filterUnits();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildUnitTile(Map<String, dynamic> unit) {
    final flat = unit['unit_flat_number'] ?? '-';
    final building = unit['soc_building_name'] ?? '';
    final memberList = (unit['member_details'] as List?) ?? const <dynamic>[];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(
          '$building - $flat',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${memberList.length} member(s)',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        children: memberList.map((member) => _buildMemberTile(member)).toList(),
      ),
    );
  }

  Widget _buildMemberTile(dynamic member) {
    final m = (member is Map) ? member : const {};
    final first = m['member_first_name']?.toString() ?? '';
    final last = m['member_last_name']?.toString() ?? '';
    final name = '$first $last'.trim();
    final mobile = m['member_mobile_number']?.toString().trim() ?? '';
    final hasMobile = mobile.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  Theme.of(context).primaryColor.withValues(alpha: 26),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '-',
                style: const TextStyle(color: Colors.black87),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isNotEmpty ? name : '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  if (hasMobile)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        mobile,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ),
                ],
              ),
            ),
            if (hasMobile && widget.config.callsEnabled)
              Container(
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: () => _callMember(mobile, memberName: name),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberList() {
    return Expanded(
      child: ValueListenableBuilder<List<dynamic>>(
        valueListenable: _filteredUnits,
        builder: (context, units, _) {
          if (_isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.black),
            );
          }
          if (units.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No members found',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: units.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final unit = units[index];
              if (unit is! Map<String, dynamic>) {
                return const SizedBox.shrink();
              }
              return _buildUnitTile(unit);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Intercom',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            color: Colors.black,
            onPressed: _openCallHistory,
            tooltip: 'Call History',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildMemberList(),
        ],
      ),
    );
  }
}

class GuardIntercomCallHistoryScreen extends StatefulWidget {
  const GuardIntercomCallHistoryScreen({
    super.key,
    required this.host,
    required this.fromNumber,
    required this.callsEnabled,
    required this.onCallBack,
  });

  final FeatureHost host;
  final String fromNumber;
  final bool callsEnabled;
  final Future<void> Function(String toNumber, String memberName) onCallBack;

  @override
  State<GuardIntercomCallHistoryScreen> createState() =>
      _GuardIntercomCallHistoryScreenState();
}

class _GuardIntercomCallHistoryScreenState
    extends State<GuardIntercomCallHistoryScreen> {
  late final GuardIntercomApi _api = GuardIntercomApi.fromHost(widget.host);

  bool _isLoading = true;
  List<dynamic> _callLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchCallLogs();
  }

  Future<void> _fetchCallLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _api.fetchCallHistory(fromNumber: widget.fromNumber);
      setState(() => _callLogs = logs);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load call logs: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      if (dateTime.isAfter(today)) {
        return 'Today, ${DateFormat('h:mm a').format(dateTime)}';
      } else if (dateTime.isAfter(yesterday)) {
        return 'Yesterday, ${DateFormat('h:mm a').format(dateTime)}';
      } else {
        return DateFormat('MMM d, h:mm a').format(dateTime);
      }
    } catch (_) {
      return dateTimeString;
    }
  }

  IconData _getCallTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'incoming':
        return Icons.call_received;
      case 'outgoing':
        return Icons.call_made;
      case 'missed':
        return Icons.call_missed;
      default:
        return Icons.call;
    }
  }

  Color _getCallTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'incoming':
        return Colors.green;
      case 'outgoing':
        return Colors.blue;
      case 'missed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _callBack(dynamic log) async {
    if (!widget.callsEnabled) return;
    final map = (log is Map) ? log : const {};
    final toNumber = map['to_number']?.toString().trim() ?? '';
    final memberName = map['member_name']?.toString().trim() ?? '';
    if (toNumber.isEmpty) return;
    await widget.onCallBack(toNumber, memberName.isNotEmpty ? memberName : '-');
  }

  Widget _buildCallLogItem(dynamic log) {
    final map = (log is Map) ? log : const {};
    final callType = map['call_type']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _getCallTypeColor(callType).withValues(alpha: 26),
          child: Icon(
            _getCallTypeIcon(callType),
            color: _getCallTypeColor(callType),
          ),
        ),
        title: Text(
          map['member_name']?.toString() ??
              map['phone_number']?.toString() ??
              'Unknown',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatDateTime(map['created_at']?.toString() ?? ''),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            if (map['call_duration'] != null)
              Text(
                'Duration: ${map['call_duration']} sec',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
          ],
        ),
        trailing: widget.callsEnabled
            ? IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: () => _callBack(log),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Call History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCallLogs,
            color: Colors.black,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCallLogs,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.black),
              )
            : _callLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No call history found',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _callLogs.length,
                    itemBuilder: (context, index) {
                      return _buildCallLogItem(_callLogs[index]);
                    },
                  ),
      ),
    );
  }
}
