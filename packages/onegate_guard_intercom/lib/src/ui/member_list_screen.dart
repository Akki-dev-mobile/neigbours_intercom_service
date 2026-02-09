import 'package:flutter/material.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _callMember(String mobile, {required String memberName}) async {
    if (!widget.config.callsEnabled) return;

    try {
      final uri = Uri(scheme: 'tel', path: mobile);
      final launched = await launchUrl(uri);
      if (!launched) {
        throw Exception('Dialer not available');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening dialer...')),
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
        actions: const [],
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
