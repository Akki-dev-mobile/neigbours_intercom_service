import 'dart:convert';
import 'dart:developer';

import 'package:common_widgets/common_widgets.dart';
import 'package:dart_amqp/dart_amqp.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/entities/visitor/building_assignment.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/id_input_view.dart';

import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../visitor_in_screens/ui/request_permission_page.dart';

class UnitSelectionView extends StatefulWidget {
  Visitor? searchedVisitor;
  final Visitor visitor;
  final PurposeCategory1 purposeCategory;
  final String? comingFrom;
  final int? guestCount;
  final int? visitorId;
  final int? companyId;
  final String guestname;
  final String mobileNumber;
  final String? visitorNumber;
  final String? purposeCategoryId;
  final String? selectedSubCategoryId;
  final String? carNumber;

  UnitSelectionView(Visitor? searchedVisitor,
      {Key? key,
      required this.visitor,
      this.carNumber,
      required this.purposeCategory,
      this.comingFrom,
      this.guestCount,
      this.companyId,
      this.visitorId,
      required this.guestname,
      required this.mobileNumber,
      this.visitorNumber,
      this.purposeCategoryId,
      this.selectedSubCategoryId})
      : super(key: key);

  @override
  State<UnitSelectionView> createState() => _UnitSelectionViewState();
}

class _UnitSelectionViewState extends State<UnitSelectionView> {
  final Dio _dio = Dio();
  final PreferenceUtils preferenceUtils = GetIt.I<PreferenceUtils>();
  final GateStorage gateStorage = GateStorage();
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<List<dynamic>> _filteredMembersNotifier =
      ValueNotifier([]);
  final ValueNotifier<Set<String>> _selectedMembersNotifier = ValueNotifier({});
  final ValueNotifier<Set<int>> _selectedUnitsNotifier = ValueNotifier({});
  final remoteDataSource = RemoteDataSource(
    DioSingleton.instance1,
    DioSingleton.instance2,
    DioSingleton.instance3,
  );
  late Client amqpClient;
  Set<int> selectedMembers = {};
  Set<int> selectedUnits = {};
  String? selectedgate;
  List<dynamic> _allMembers = [];
  List<dynamic> _approvals = [];
  String? companyId;
  String? companyName;
  bool isLoading = true;
  Map<String, dynamic> savedMemberUnitDetails = {};
  Set<String> selectedUserIds = {};
  List<int> selectedMemberIds = [];
  List<String> selectedBuildingUnits = [];
  String formattedInTime =
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
  String? approvalStatus = "Waiting for approval...";
  bool? _membersApproval;
  late Future<void> _initializeFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterMembers);
    _fetchCompanyId();
    _loadVisitorSettings();
    _initializeFuture = _initializeMembers(); // Initialize the Future once
    log("${selectedUnits} here is this");
    log("${widget.comingFrom} here is this");
  }

  Future<void> _loadVisitorSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _membersApproval = await prefs.getBool('membersApproval');
  }

  @override
  void dispose() {
    _filteredMembersNotifier.dispose();
    _selectedMembersNotifier.dispose();
    _searchController.dispose();
    print("here i am${widget.selectedSubCategoryId}");
    super.dispose();
  }

  // API Methods
  Future<void> _fetchCompanyId() async {
    companyId = await gateStorage.getSocietyId();
    final companyDetails = await gateStorage.getSocietyDetails();
    companyName = companyDetails['societyName'];

    setState(() {});
  }

  Future<void> _initializeMembers() async {
    final members = await remoteDataSource.getMembersList();
    _allMembers = members;
    _filteredMembersNotifier.value = members;
  }

  // Search and Filter Methods
  void _filterMembers() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.length >= 3) {
      _filteredMembersNotifier.value = _allMembers.where((member) {
        final memberName =
            member['member_name']?.toLowerCase().contains(query) ?? false;
        final unitNumber =
            member['unit_flat_number']?.toLowerCase().contains(query) ?? false;
        return memberName || unitNumber;
      }).toList();
    } else {
      _filteredMembersNotifier.value = _allMembers;
    }
  }

  void _showSelectedMembersBottomSheet(Set<String> selectedMembers) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected Members',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Members List
              // Members List
              Expanded(
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable: _selectedMembersNotifier,
                  builder: (context, selectedMembers, _) {
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: selectedMembers.length,
                      itemBuilder: (context, index) {
                        final member = selectedMembers.elementAt(index);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[200],
                              child: const Icon(
                                Icons.person,
                                color: Colors.black,
                              ),
                            ),
                            title: Text(
                              member,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                final updatedMembers = Set<String>.from(
                                    _selectedMembersNotifier.value);
                                updatedMembers.remove(member);
                                _selectedMembersNotifier.value = updatedMembers;
                                if (updatedMembers.isEmpty) {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // Bottom Buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 1,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Colors.black),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedMembersNotifier.value = {};
                          });
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Clear All',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          // // Add your confirm logic here
                          Navigator.pop(context);
                          _handleSelectionSubmit(selectedMembers);
                        },
                        child: const Text(
                          'Confirm',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Storage Methods
  Future<void> saveMemberAndUnitToPrefs(
      Set<String> memberDetails, Set<int> unitIDs) async {
    savedMemberUnitDetails = {
      'member_details': formattedMemberDetails,
      'unit_ids': unitIDs.whereType<int>().toList(),
      'member_ids': selectedMemberIds.toList(),
      'building_unit': selectedBuildingUnits.toList(),
    };
    log('Saved member and unit details: ${jsonEncode(savedMemberUnitDetails)}');
  }

  // UI Methods
  Widget _buildSearchField(BuildContext context) {
    return CustomForm.textField(
      'Search Members',
      titleColor: Theme.of(context).colorScheme.onSurface,
      hintColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
      hintText: 'Search Members',
      textController: _searchController,
      onChanged: (_) {
        _searchController.text.trim().length >= 3
            ? _filterMembers()
            : _filteredMembersNotifier.value = _allMembers;
      },
      suffixIcon: _searchController.text.isNotEmpty
          ? IconButton(
              icon: const Icon(
                Ionicons.close,
                color: Colors.red,
              ),
              onPressed: () {
                _searchController.clear();
                _filteredMembersNotifier.value = _allMembers;
              },
            )
          : null,
    );
  }

  Widget _buildMemberList(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _selectedMembersNotifier,
      builder: (context, selectedMembers, child) {
        return ValueListenableBuilder<List<dynamic>>(
          valueListenable: _filteredMembersNotifier,
          builder: (context, filteredMembers, child) {
            if (filteredMembers.isEmpty) {
              return _buildEmptyState();
            }
            return _buildMemberListView(filteredMembers, selectedMembers);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.groups_outlined,
            size: 60,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Members Found.\nSearch members by their name or flat',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberListView(
      List<dynamic> filteredMembers, Set<String> selectedMembers) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filteredMembers.length,
      itemBuilder: (context, index) =>
          _buildMemberTile(filteredMembers[index], selectedMembers),
    );
  }

  Widget _buildMemberTile(dynamic member, Set<String> selectedMembers) {
    final memberDetails = member['member_details'] as List<dynamic>? ?? [];
    final firstMemberName = memberDetails.isNotEmpty
        ? memberDetails.first['member_first_name'] ?? 'N/A'
        : 'N/A';
    final additionalMembersCount =
        memberDetails.length > 1 ? '+${memberDetails.length - 1}' : '';

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Theme.of(context).colorScheme.onSurface.withAlpha(20),
      ),
      child: ExpansionTile(
        iconColor: Colors.redAccent,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        leading: Icon(
          Symbols.location_away,
          color: Theme.of(context).colorScheme.onSurface,
          size: 32,
        ),
        title: Text(
          member['unit_flat_number'] ?? 'N/A',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Text(
          '$firstMemberName $additionalMembersCount',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.w300,
              color: Theme.of(context).colorScheme.onSurface),
        ),
        collapsedIconColor: Theme.of(context).colorScheme.onSurface,
        children: _buildMemberDetailsList(memberDetails, member),
      ),
    );
  }

  List<Widget> _buildMemberDetailsList(
      List<dynamic> memberDetails, dynamic member) {
    return [
      ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: memberDetails.length,
        separatorBuilder: (context, index) => Divider(
          color: Theme.of(context).dividerColor,
          height: 1,
        ),
        itemBuilder: (context, index) =>
            _buildMemberDetailsItem(memberDetails[index], member),
      ),
    ];
  }

  Widget _buildMemberDetailsItem(dynamic detail, dynamic member) {
    final firstName = detail['member_first_name'] ?? 'N/A';
    final lastName = detail['member_last_name']?.toString() ?? 'N/A';
    final userId = detail['user_id']?.toString() ?? 'N/A';
    final unitId = member['fk_unit_id'] ?? 'N/A';
    final memberId = member["member_id"];
    final buildingUnit = member["building_unit"] ?? 'N/A';
    final memberMobileNo = member["member_mobile_number"];

    return ListTile(
      contentPadding: const EdgeInsets.only(top: 3, bottom: 10),
      title: Text(
        '$firstName $lastName',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      onTap: () => _handleMemberSelection(
        firstName,
        userId,
        memberId,
        buildingUnit,
        unitId,
        memberMobileNo,
      ),
      trailing: Icon(
        _selectedMembersNotifier.value.contains(firstName)
            ? Ionicons.checkmark_circle
            : Icons.add_circle_outline,
        color: _selectedMembersNotifier.value.contains(firstName)
            ? Colors.green
            : null,
      ),
    );
  }

  List<Map<String, dynamic>> formattedMemberDetails = [];

  Future<void> _handleMemberSelection(
    String firstName,
    String userId,
    dynamic memberId,
    String buildingUnit,
    dynamic unitId,
    String? memberMobileNo,
  ) async {
    final updatedMembers = Set<String>.from(_selectedMembersNotifier.value);

    if (_selectedMembersNotifier.value.contains(firstName)) {
      updatedMembers.remove(firstName);
      selectedUserIds.remove(userId);
      selectedMemberIds.remove(memberId);
      selectedBuildingUnits.remove(buildingUnit);
      formattedMemberDetails
          .removeWhere((member) => member["name"] == firstName);
    } else {
      updatedMembers.add(firstName);
      selectedUserIds.add(userId);
      _addMemberIds(memberId);
      selectedBuildingUnits.add(buildingUnit);

      // Add formatted member details
      formattedMemberDetails.add({
        "name": firstName,
        "unit_id": unitId,
        "member_ids": memberId,
        "building_unit": buildingUnit
      });

      await _saveMemberMobileNumber(memberMobileNo);
    }

    _selectedMembersNotifier.value = updatedMembers;
    _updateSelectedUnits(unitId);
  }

  void _addMemberIds(dynamic memberId) {
    final cleanedMemberIds = memberId
        .toString()
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();

    for (final id in cleanedMemberIds) {
      try {
        selectedMemberIds.add(int.parse(id));
      } catch (e) {
        log("Error parsing ID: $id, Error: $e");
      }
    }
  }

  Future<void> _saveMemberMobileNumber(String? memberMobileNo) async {
    if (memberMobileNo != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_member_mobile_numbers', memberMobileNo);
      log("Saved selected member mobile number: $memberMobileNo");
    }
  }

  void _updateSelectedUnits(dynamic unitId) {
    final updateUnits = Set<int>.from(selectedUnits);
    if (selectedUnits.contains(unitId)) {
      updateUnits.remove(unitId);
    } else {
      selectedUnits.add(unitId);
    }
    _selectedUnitsNotifier.value = updateUnits;
  }

  bool _isCheckedIn = false; // ✅ Ensures check-in happens only once

  // Main Build Method
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (widget.searchedVisitor != null) {
          Navigator.pop(context);
          return false; // Prevent default back navigation.
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => GateDashboardView()),
            (Route<dynamic> route) => false,
          );
          return false; // Prevent default back navigation.
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Select"),
        ),
        body: SafeArea(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TabBar(
                            indicator: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.black,
                            dividerColor: Colors.transparent,
                            indicatorSize: TabBarIndicatorSize.tab,
                            tabs: [
                              Tab(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: const Text(
                                    'Select Units/Members',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              Tab(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: const Text(
                                    'Society Office',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // First Tab - Select Units/Members
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 0.0, horizontal: 10),
                                    child: _buildSearchField(context),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 40.0),
                                      child: _buildMemberList(context),
                                    ),
                                  ),
                                ],
                              ),

                              // Selected Members Bottom Sheet
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: ValueListenableBuilder<Set<String>>(
                                  valueListenable: _selectedMembersNotifier,
                                  builder: (context, selectedMember, _) {
                                    if (selectedMember.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Builder(
                                      builder: (context) {
                                        if (DefaultTabController.of(context)
                                                .index !=
                                            0) {
                                          return const SizedBox.shrink();
                                        }
                                        return Container(
                                          color: Colors.black,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Material(
                                                elevation: 8,
                                                color: Colors.black,
                                                child: InkWell(
                                                  onTap: () =>
                                                      _showSelectedMembersBottomSheet(
                                                          selectedMember),
                                                  child: Padding(
                                                    padding: EdgeInsets.only(
                                                      left: 20,
                                                      right: 20,
                                                      top: 16,
                                                      bottom: MediaQuery.of(
                                                                      context)
                                                                  .viewInsets
                                                                  .bottom >
                                                              0
                                                          ? MediaQuery.of(
                                                                  context)
                                                              .viewInsets
                                                              .bottom
                                                          : 16 +
                                                              MediaQuery.of(
                                                                      context)
                                                                  .padding
                                                                  .bottom,
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            const Icon(
                                                                Icons.people,
                                                                color: Colors
                                                                    .white),
                                                            const SizedBox(
                                                                width: 8),
                                                            Text(
                                                              selectedMember
                                                                          .length >
                                                                      1
                                                                  ? '${selectedMember.length} Selected'
                                                                  : selectedMember
                                                                      .first,
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .titleLarge
                                                                  ?.copyWith(
                                                                      color: Colors
                                                                          .white),
                                                            ),
                                                          ],
                                                        ),
                                                        ElevatedButton.icon(
                                                          style: ButtonStyle(
                                                            foregroundColor:
                                                                MaterialStateProperty
                                                                    .all<Color>(
                                                              const Color(
                                                                  0xFF7D7C7C),
                                                            ),
                                                            backgroundColor:
                                                                MaterialStateProperty
                                                                    .all<Color>(
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .surface,
                                                            ),
                                                            elevation:
                                                                MaterialStateProperty
                                                                    .resolveWith<
                                                                        double>(
                                                              (Set<MaterialState>
                                                                      states) =>
                                                                  states.contains(
                                                                          MaterialState
                                                                              .pressed)
                                                                      ? 8
                                                                      : 0,
                                                            ),
                                                            shape: MaterialStateProperty
                                                                .all<
                                                                    RoundedRectangleBorder>(
                                                              RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            15),
                                                              ),
                                                            ),
                                                            padding:
                                                                MaterialStateProperty
                                                                    .all<
                                                                        EdgeInsetsGeometry>(
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                horizontal: 20,
                                                                vertical: 10,
                                                              ),
                                                            ),
                                                          ),
                                                          onPressed: () =>
                                                              _showSelectedMembersBottomSheet(
                                                                  selectedMember),
                                                          label: Text(
                                                            "view",
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodyLarge!
                                                                .copyWith(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .colorScheme
                                                                      .onSurface,
                                                                ),
                                                          ),
                                                          icon: const Icon(
                                                            Icons
                                                                .keyboard_arrow_up,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      // Second Tab - Society Office
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.business,
                              size: 64,
                              color: Colors.black,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Society Office',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 24),
                            // In the Society Office tab, update the ElevatedButton onPressed handler:
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                try {
                                  setState(() {
                                    _isLoading = true; // Show loading state
                                  });

                                  // Create building assignment
                                  final buildingAssignment = BuildingAssignment(
                                    id: null,
                                    visitor_id: widget.visitor.id,
                                    visitor_log_id: null,
                                    company_id: int.parse(companyId.toString()),
                                    building_id: 0,
                                    unit_id: ["0001"],
                                  );

                                  // Create visitor log data
                                  final visitorLogData = VisitorLog(
                                    visitor_id: widget.visitor.id ?? 0,
                                    visitor_purpose_category_id:
                                        widget.purposeCategoryId == null
                                            ? 1
                                            : int.parse(widget.purposeCategoryId
                                                .toString()),
                                    visitor_purpose_sub_category_id:
                                        widget.selectedSubCategoryId != null
                                            ? int.parse(widget
                                                .selectedSubCategoryId
                                                .toString())
                                            : null,
                                    visitor_count: widget.guestCount ?? 0,
                                    visitor: widget.visitor,
                                    visitor_check_in:
                                        DateTime.parse(formattedInTime),
                                    visitor_card_number: widget.visitorNumber,
                                    visitor_coming_from: widget.comingFrom,
                                    visitor_building_assignment: [
                                      buildingAssignment
                                    ],
                                    visitor_card_id: null,
                                    carNumber: widget.carNumber,
                                    company_id: int.parse(companyId.toString()),
                                    is_checked_out: false,
                                  );

                                  // Save society office details to preferences
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  final societyOfficeMemberDetails = [
                                    {
                                      "name": "Society Office",
                                      "unit_name": "Cyberone",
                                      "unit_id": 0001,
                                      "member_ids": 0,
                                      "building_unit": "0001"
                                    }
                                  ];

                                  await prefs.setString(
                                    'member_details',
                                    json.encode(societyOfficeMemberDetails),
                                  );

                                  // Perform check-in
                                  await remoteDataSource.checkIn(
                                      visitorLogData, true);

                                  // Show success message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Visitor checked in successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );

                                  // Navigate to dashboard
                                  if (mounted) {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const GateDashboardView(),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                } catch (e) {
                                  log('Error during check-in: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Error during check-in. Please try again.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isLoading = false;
                                    });
                                  }
                                }
                              },
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Tap to Check-in',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionBar(Set<String> selectedMember) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      color: Theme.of(context).colorScheme.onSurface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            selectedMember.length > 1
                ? "${selectedMember.first} +${selectedMember.length - 1}"
                : selectedMember.first,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.surface,
                ),
          ),
          ElevatedButton.icon(
            style: _buildElevatedButtonStyle(),
            onPressed: () => _handleSelectionSubmit(selectedMember),
            label: Text(
              (selectedMember.length > 1) ? "Allow" : "Next",
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            icon: Icon(
              Icons.navigate_before,
              size: 32,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _buildElevatedButtonStyle() {
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.all<Color>(const Color(0xFF7D7C7C)),
      backgroundColor: WidgetStateProperty.all<Color>(
        Theme.of(context).colorScheme.surface,
      ),
      elevation: WidgetStateProperty.resolveWith<double>(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.pressed) ? 8 : 0,
      ),
      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
        const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
      ),
    );
  }

  // Selection Submission Methods
  Future<void> _handleSelectionSubmit(Set<String> selectedMember) async {
    log("Handling selection submit...");
    await saveMemberAndUnitToPrefs(selectedMember, selectedUnits);

    try {
      final visitorLogData = await _prepareVisitorLogData();

      if (selectedMember.length == 1) {
        // Single member selection flow
        await _handleSingleMemberSelection(visitorLogData);
      } else {
        // Multiple members selection flow
        await _handleMultipleMemberSelection(visitorLogData);
      }
    } catch (e) {
      log("Error in selection submit: $e");
      _showErrorSnackbar("Error processing selection");
    }
  }

  Future<void> _handleSingleMemberSelection(VisitorLog visitorLogData) async {
    // Step 1: Check-in
    if (!_isCheckedIn) {
      await remoteDataSource.checkIn(visitorLogData, statusallowed);
      _isCheckedIn = true;
    }

    // Step 2: Send FCM notification and navigate
    try {
      final userId = selectedUserIds.first;
      final selectedMobileNumbers = await _getSelectedMobileNumbers();
      final requestData =
          await _prepareRequestData(userId, selectedMobileNumbers);

      final response = await Dio().post(
        'https://stggateapi.cubeone.in/api/visitor/sendFcmNotification',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: requestData,
      );

      if (response.statusCode == 200) {
        log("✅ FCM notification sent successfully");

        // Parse the response
        final responseData = response.data;
        final message = responseData['message'] as String?;

        if (message?.toLowerCase() == "visitor is always allowed") {
          await remoteDataSource.checkIn(visitorLogData, statusallowed = true);

          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const GateDashboardView(),
            ),
          );
        } else {
          // Normal flow - navigate to RequestPermissionPage
          final prefs = await SharedPreferences.getInstance();
          final logID = prefs.getString("visitor_log");

          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RequestPermissionPage(
                visitor: widget.visitor,
                unitList: selectedBuildingUnits,
                visitorLog: visitorLogData,
                logID: logID,
              ),
            ),
          );
        }
      }
    } catch (e) {
      log("Error sending FCM notification: $e");
      _showErrorSnackbar("Error sending notification");
    }
  }

  Future<void> _handleMultipleMemberSelection(VisitorLog visitorLogData) async {
    await _showApprovedDialog(context, visitorLogData, onSuccess: () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const GateDashboardView()),
      );
    });
  }

  Future<void> _showApprovedDialog(BuildContext context, VisitorLog data,
      {VoidCallback? onSuccess}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Lottie.asset(
                      'assets/json/approved.json',
                      width: 150,
                      height: 150,
                      repeat: false,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Visitor Allowed By Gatekeeper",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _isLoading
                        ? const _LoadingIndicator()
                        : CustomLargeBtn(
                            onPressed: () async {
                              if (_isButtonDisabled) return;
                              await _handleApprovedDialogButton(
                                context,
                                data,
                                setState,
                                onSuccess,
                              );
                            },
                            text: "Continue",
                            disabled: _isButtonDisabled,
                          ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleApprovedDialogButton(
    BuildContext context,
    VisitorLog data,
    StateSetter setState,
    VoidCallback? onSuccess,
  ) async {
    setState(() {
      _isLoading = true;
      _isButtonDisabled = true;
    });

    try {
      if (!_isCheckedIn) {
        await remoteDataSource.checkIn(data, statusallowed);
        _isCheckedIn = true;
      }

      Navigator.pop(context);

      if (onSuccess != null) {
        onSuccess();
      }
    } catch (e) {
      log('Error in approved dialog: $e');
      setState(() {
        _isLoading = false;
        _isButtonDisabled = false;
      });
      _showErrorSnackbar('Error processing approval');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  bool _validateSelection(Set<String> selectedMember) {
    if (selectedMember.length != 1 || selectedUnits.length != 1) {
      _handleInvalidSelection();
      return false;
    }
    return true;
  }

// Update the _prepareVisitorLogData method
  Future<VisitorLog> _prepareVisitorLogData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? visitorId = prefs.getString('visitorId');
    final companyDetails = await gateStorage.getSocietyDetails();
    final companyName = companyDetails['societyName'];
    final selectedGateName = prefs.getString('selected_gate');

    List<int> unitIds = [];
    if (formattedMemberDetails != null && formattedMemberDetails is List) {
      unitIds = formattedMemberDetails
          .map((member) => member['unit_id'])
          .where((id) => id != null)
          .map((id) => int.parse(id.toString()))
          .toList();
    }

    // Map unit IDs to BuildingAssignment objects
    List<BuildingAssignment> buildingAssignments = unitIds.map((unitId) {
      return BuildingAssignment(
        id: null,
        visitor_id: widget.visitor.id,
        visitor_log_id: null,
        company_id: int.parse(companyId.toString()),
        building_id: 0,
        unit_id: [unitId.toString()],
      );
    }).toList();
    print("subbb${widget.selectedSubCategoryId.toString()}");
    try {
      final String memberDetailsJson = json.encode(formattedMemberDetails);
      await prefs.setString('member_details', memberDetailsJson);
      print('Successfully saved member details: $memberDetailsJson');
    } catch (e) {
      print('Error saving member details: $e');
    }

    return VisitorLog(
      visitor_id: int.parse(widget.visitor.id.toString()) ?? 0,
      visitor_purpose_category_id:
          int.parse(widget.purposeCategoryId.toString()),
      visitor_purpose_sub_category_id: widget.selectedSubCategoryId != null
          ? int.parse(widget.selectedSubCategoryId.toString())
          : null,
      visitor_count: widget.guestCount ?? 0,
      visitor_check_in: DateTime.parse(formattedInTime),
      visitor_card_number: widget.visitorNumber,
      visitor_coming_from: widget.comingFrom,
      visitor_card_id: null,
      company_id: int.parse(companyId.toString()),
      carNumber: widget.carNumber,
      visitor_building_assignment: buildingAssignments,
      is_checked_out: false,
    );
  }

// Helper method to retrieve the saved member details
  Future<List<Map<String, dynamic>>> getSavedMemberDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final String? memberDetailsJson = prefs.getString('member_details');

    if (memberDetailsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(memberDetailsJson);
        return List<Map<String, dynamic>>.from(decoded);
      } catch (e) {
        print('Error retrieving member details: $e');
        return [];
      }
    }
    return [];
  }

  // Update the _handleInvalidSelection method
  void _handleInvalidSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final String? visitorId = prefs.getString('visitorId');
    final companyDetails = await gateStorage.getSocietyDetails();
    final companyName = companyDetails['societyName'];
    // Extract unit IDs from formattedMemberDetails
    List<int> unitIds = [];
    if (formattedMemberDetails != null && formattedMemberDetails is List) {
      unitIds = formattedMemberDetails
          .map((member) => member['unit_id'])
          .where((id) => id != null)
          .map((id) => int.parse(id.toString()))
          .toList();
    }
    print("subbb${widget.selectedSubCategoryId.toString()}");
    // Map unit IDs to BuildingAssignment objects
    List<BuildingAssignment> buildingAssignments = unitIds.map((unitId) {
      return BuildingAssignment(
        id: null,
        visitor_id: widget.visitor.id,
        visitor_log_id: null,
        company_id: int.parse(companyId.toString()),
        building_id: 0,
        unit_id: [unitId.toString()],
      );
    }).toList();

    final selectedGateName = prefs.getString('selected_gate');

    final visitorLogData = VisitorLog(
        visitor_id: widget.visitor.id ?? 0,
        visitor_purpose_category_id: widget.purposeCategoryId == null
            ? 1
            : int.parse(widget.purposeCategoryId.toString()),
        visitor_purpose_sub_category_id: widget.selectedSubCategoryId != null
            ? int.parse(widget.selectedSubCategoryId.toString())
            : null,
        visitor_count: widget.guestCount ?? 0,
        visitor_check_in: DateTime.parse(formattedInTime),
        visitor_card_number: widget.visitorNumber,
        visitor_coming_from: widget.comingFrom,
        visitor_building_assignment: buildingAssignments,
        visitor_card_id: null,
        carNumber: widget.carNumber,
        company_id: int.parse(companyId.toString()),
        is_checked_out: false);
    final String memberDetailsJson = json.encode(formattedMemberDetails);
    await prefs.setString('member_details', memberDetailsJson);
    await _showApprovedDialog(context, visitorLogData);
  }

  Future<List<String>> _getSelectedMobileNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMobileNumbersJson =
        prefs.getString('selected_member_mobile_numbers') ?? '[]';
    // Load the selected gate from SharedPreferences
    selectedgate = prefs.getString('selected_gate');
    final cleanedJson =
        savedMobileNumbersJson.trim().replaceAll(RegExp(r'^,+|,+$'), '');
    return cleanedJson.split(',').where((number) => number.isNotEmpty).toList();
  }

  Future<Map<String, String>> _prepareRequestData(
    String userId,
    List<String> savedMobileNumbers,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final visitorLogId = prefs.getString("visitor_log") ?? "";
    final String? visitorId = prefs.getString('visitorId');

    // Log for debugging
    log("Visitor Log ID: $visitorLogId");

    return {
      'company_id': companyId.toString(),
      'name': widget.guestname,
      'mobile': widget.mobileNumber,
      'purpose': "Guest",
      'in_time': formattedInTime,
      'user_id': (int.tryParse(userId) == null || int.tryParse(userId) == 0)
          ? "234567"
          : int.parse(userId).toString(),
      'visitor_count': widget.guestCount.toString(),
      'member_mobile_number': "918452060059",
      'visitor_id': visitorId ?? searchedVisitor!.id.toString(),
      'purpose_category': widget.purposeCategory.categoryId.toString() == "3"
          ? "delivery"
          : widget.purposeCategory.categoryId.toString(),
      'visitor_log_id': visitorLogId,
      'coming_from': widget.comingFrom.toString() ?? "Bandra",
      'member_id': selectedMemberIds.isNotEmpty
          ? selectedMemberIds.first.toString()
          : "232",
      'company_name': companyName ?? "",
    };
  }

  Future<void> setupAMQPReceiver() async {
    try {
      log("Initializing AMQP Receiver...");

      // Initialize AMQP client with connection settings
      amqpClient = Client(
        settings: ConnectionSettings(
          host: "65.1.230.119",
          authProvider:
              const PlainAuthenticator("dinesh.koli", "7nqRG&I!FesI&7zCrii0"),
        ),
      );

      log("Connecting to RabbitMQ server...");
      await amqpClient.connect();
      log("Connection to RabbitMQ server established successfully.");

      // Define the queue name dynamically based on the mobile number
      final queueName = "visitor_approval_77525_${widget.mobileNumber}";
      log("Queue Name: $queueName");

      Channel channel = await amqpClient.channel();
      log("Channel opened.");

      Queue queue = await channel.queue(queueName, durable: false);
      log("Queue declared: $queueName");

      const String exchangeName = "logs"; // Example exchange name
      final Exchange exchange = await channel.exchange(
        exchangeName,
        ExchangeType.FANOUT,
        durable: false,
      );
      log("Exchange bound: $exchangeName");

      await queue.bind(exchange, "routing_key_placeholder");
      log("Queue bound to exchange with routing key.");

      // Start consuming messages from the queue
      Consumer consumer = await queue.consume();

      log("Consumer registered for queue. Waiting for messages...");

      // Listen for messages on the queue
      consumer.listen((AmqpMessage message) {
        log("Message received from queue.");

        try {
          // Decode the message payload
          final payload = utf8.decode(message.payload as List<int>);
          log("Raw Message Payload: $payload");

          // Parse the message as JSON
          final response = jsonDecode(payload);
          log("Decoded Message: $response");

          // Extract the approval status from the message
          final status = response['status'];
          log("Approval Status: $status");

          showApprovalDialog(status);

          // Update the dialog dynamically
          // setState(() {
          //   approvalStatus = status;
          // });

          // Acknowledge the message
          message.ack();
        } catch (e) {
          log("Error processing message: $e");
        }
      });
    } catch (e) {
      log("Error setting up AMQP Receiver: $e");
    }
  }

  Future<void> showApprovalDialog(approvalStatusNew) async {
    // Ensure `approvalStatus` starts with "Waiting for approval..."
    setState(() {
      approvalStatus = "Waiting for approval...";
    });

    await setupAMQPReceiver();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text("Approval Status"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (approvalStatus == "Waiting for approval...")
                    const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    approvalStatusNew,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
          actions: [
            if (approvalStatus == "Approved" || approvalStatus == "Rejected")
              TextButton(
                onPressed: () {
                  setState(() {
                    approvalStatus = null;
                  });
                  Navigator.pop(context);
                },
                child: const Text("Close"),
              ),
          ],
        );
      },
    ).then((_) {
      setState(() {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const GateDashboardView()));
      });
    });
  }

  bool _isButtonDisabled = false;

  void _setLoading(bool isLoading) {
    setState(() {
      _isLoading = isLoading;
    });
  }

  bool statusallowed = false;

  Future<void> _notificationSent(BuildContext context, VisitorLog data) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                          ),
                        ),
                        Lottie.asset(
                          'assets/json/approved.json',
                          width: 180,
                          height: 180,
                          repeat: false,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Notification Sent Successfully",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Please wait for member's response. You can check the status in the approval screen.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? Column(
                            children: [
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Redirecting...",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: !_isButtonDisabled
                                  ? LinearGradient(
                                      colors: [
                                        Theme.of(context).primaryColor,
                                        Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.8),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color:
                                  _isButtonDisabled ? Colors.grey[300] : null,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: !_isButtonDisabled
                                  ? [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.3),
                                        spreadRadius: 0,
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: MaterialButton(
                              onPressed: _isButtonDisabled
                                  ? null
                                  : () async {
                                      setState(() {
                                        _isLoading = true;
                                        _isButtonDisabled = true;
                                      });

                                      await Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const GateDashboardView(),
                                        ),
                                      );
                                    },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: _isButtonDisabled
                                        ? Colors.grey[500]
                                        : Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Check Approval Status",
                                    style: TextStyle(
                                      color: _isButtonDisabled
                                          ? Colors.grey[500]
                                          : Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(
          "Please wait, checking in...",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
