import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'call_history.dart';

class MemberList extends StatefulWidget {
  const MemberList({Key? key}) : super(key: key);

  @override
  _MemberListState createState() => _MemberListState();
}

class _MemberListState extends State<MemberList> {
  final TextEditingController _searchController = TextEditingController();
  final RemoteDataSource remoteDataSource = RemoteDataSource();
  final ValueNotifier<List<dynamic>> _filteredUnits = ValueNotifier([]);
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
      final response = await remoteDataSource.getMembersList();
      final members = response['data'] as List<dynamic>;
      setState(() {
        _allUnits = members;
        _filteredUnits.value = members;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load members: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterUnits() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.length >= 3) {
      _filteredUnits.value = _allUnits.where((unit) {
        final flat = unit['unit_flat_number']?.toLowerCase() ?? '';
        final building = unit['soc_building_name']?.toLowerCase() ?? '';
        final members = (unit['member_details'] as List<dynamic>?) ??
            (unit['rows'] as List<dynamic>?) ??
            [];

        final matchInUnit = flat.contains(query) || building.contains(query);
        final matchInMembers = members.any((m) {
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
    final memberList = (unit['member_details'] as List<dynamic>?) ??
        (unit['rows'] as List<dynamic>?) ??
        [];

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
    final name =
        '${member['member_first_name'] ?? ''} ${member['member_last_name'] ?? ''}';
    final mobile = member['member_mobile_number']?.toString().trim() ?? '';
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
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
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
                    name,
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
            if (hasMobile)
              Container(
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: () {
                    remoteDataSource.callMember(mobile, context, name: name);
                  },
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
                child: DashboardLoaderIcon(
              color: Colors.black,
            ));
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
            itemBuilder: (context, index) => _buildUnitTile(units[index]),
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
          "Intercom Services",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            color: Colors.black,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const CallHistoryScreen(fromNumber: "918452060059"),
                ),
              );
            },
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
