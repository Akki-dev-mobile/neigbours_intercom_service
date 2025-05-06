import 'dart:convert';
import 'dart:developer';

import 'package:common_widgets/common_widgets.dart';
import 'package:dart_amqp/dart_amqp.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/visitor/building_assignment.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_screens/ui/request_permission_page.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_screens/widgets/request_2.dart';
import 'package:flutter_onegate/services/app_calling/app_to_app.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import "package:intl/intl.dart";
import '../../../self_entry/self_home_view.dart';
import '../../../self_entry/ui/self_profile_view.dart';

class UnitSelectionView extends StatefulWidget {
  final int? from;
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
  final bool selfcheckinFlow;

  final bool? isVerified;
  final bool? isKioskModeEnabled;

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
      this.selectedSubCategoryId,
      this.isVerified,
      this.isKioskModeEnabled = true,
      this.from,
      this.selfcheckinFlow = false})
      : super(key: key);

  @override
  State<UnitSelectionView> createState() => _UnitSelectionViewState();
}

class _UnitSelectionViewState extends State<UnitSelectionView> {
  // final Dio _dio = Dio();
  final PreferenceUtils preferenceUtils = GetIt.I<PreferenceUtils>();
  final GateStorage gateStorage = GateStorage();
  final SocketService socketService = SocketService();
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<List<dynamic>> _filteredMembersNotifier =
      ValueNotifier([]);
  final ValueNotifier<Set<String>> _selectedMembersNotifier = ValueNotifier({});
  final ValueNotifier<Set<int>> _selectedUnitsNotifier = ValueNotifier({});
  final RemoteDataSource remoteDataSource = RemoteDataSource();
  late Client amqpClient;
  Set<int> selectedMembers = {};
  Set<int> selectedUnits = {};
  String? selectedgate;
  List<dynamic> _allMembers = [];
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
    _initializeSocketConnection();
    _initializeFuture = _initializeMembers();
    log("$selectedUnits here is this");
    _isLoading = true; // Set loading state before fetching members
    _initializeMembers().then((_) {
      if (mounted) {
        setState(() {
          _isLoading = false; // Turn off loading state after members are loaded
        });
      }
    });
    log("${widget.comingFrom} here is this");
  }

  // API Methods
  Future<void> _fetchCompanyId() async {
    companyId = await gateStorage.getSocietyId();
    final companyDetails = await gateStorage.getSocietyDetails();

    companyName = companyDetails['societyName'];
// companyId = companyDetails['societyId'];
    setState(() {});
  }

  void _initializeSocketConnection() {
    socketService.initSocket(companyId.toString(), "onegate");
  }

  Future<void> _loadVisitorSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _membersApproval = prefs.getBool('membersApproval');
  }

  @override
  void dispose() {
    socketService.disconnect();
    _filteredMembersNotifier.dispose();
    _selectedMembersNotifier.dispose();
    _searchController.dispose();
    print("here i am${widget.selectedSubCategoryId}");
    super.dispose();
  }

  Future<void> _initializeMembers() async {
    final members = await remoteDataSource.getMembersList();
    _allMembers = members;
    _filteredMembersNotifier.value = members;
  }

  Future<void> deleteImage() async {
    GateStorage storage = GateStorage();
    await storage.init();
    await storage.removeVisitorImage();
    print("Image successfully removed.");
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
                          _handleSelectionSubmit(selectedMembers);
                        },
                        child: Text(
                          selectedMemberSelectionLoading
                              ? "Loading..."
                              : 'Confirm',
                          style: const TextStyle(
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
      'member_old_sso_id': selectedUserIds.first
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
            if (_isLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.black,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading members...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

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
    final unitFlatNumber = member['unit_flat_number']?.toString() ?? 'N/A';
    final buildingUnit = member['building_unit']?.toString() ?? 'N/A';
    final socBuildingName = member['soc_building_name']?.toString() ?? '';

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
          '$socBuildingName - $unitFlatNumber',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Text(
          "${memberDetails.length} Member(s)",
          style: Theme.of(context).textTheme.bodySmall,
        ),
        collapsedIconColor: Theme.of(context).colorScheme.onSurface,
        children: memberDetails.isEmpty
            ? [const Text('No members available')]
            : _buildMemberDetailsList(memberDetails, member),
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
    final firstName = detail['member_first_name']?.toString() ?? 'N/A';
    final lastName = detail['member_last_name']?.toString() ?? '';
    final memberName = "$firstName $lastName";
    final userId = detail['user_id']?.toString() ?? '';
    final unitId = member['fk_unit_id'] ?? 0;
    final memberId = detail['member_id'] ?? 0;
    final buildingUnit = member['building_unit']?.toString() ?? 'N/A';
    final memberMobileNo =
        detail['member_mobile_number']?.toString().trim() ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      title: Text(
        memberName,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      // subtitle: Text(
      //   "Mobile: ${memberMobileNo.isNotEmpty ? memberMobileNo : 'N/A'}",
      //   style: Theme.of(context).textTheme.bodySmall,
      // ),
      trailing: Icon(
        _selectedMembersNotifier.value.contains(memberName)
            ? Ionicons.checkmark_circle
            : Icons.add_circle_outline,
        color: _selectedMembersNotifier.value.contains(memberName)
            ? Colors.green
            : null,
      ),
      onTap: () {
        _handleMemberSelection(
          memberName,
          userId,
          memberId,
          buildingUnit,
          unitId,
          memberMobileNo,
        );
      },
    );
  }

  List<Map<String, dynamic>> formattedMemberDetails = [];
  Set<String> selectedMobileNumbers = {};

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
      _removeMemberId(memberId); // ✅ Remove only this member's ID
      _removeMobileNumber(memberMobileNo); // ✅ Remove only this member's mobile
      selectedBuildingUnits.remove(buildingUnit);
      formattedMemberDetails
          .removeWhere((member) => member["name"] == firstName);
    } else {
      updatedMembers.add(firstName);
      selectedUserIds.add(userId);
      _addSingleMemberId(memberId); // ✅ Store only this member's ID
      _addSingleMobileNumber(
          memberMobileNo); // ✅ Store only this member's mobile
      selectedBuildingUnits.add(buildingUnit);

      // ✅ Add correct mapping between member and their own data
      formattedMemberDetails.add({
        "name": firstName,
        "unit_id": unitId,
        "member_ids": memberId, // ✅ Only this member's ID
        "building_unit": buildingUnit,
        "mobile_number": memberMobileNo, // ✅ Only this member's mobile number
        "member_old_sso_id": selectedUserIds.first
      });
    }

    _selectedMembersNotifier.value = updatedMembers;
    _updateSelectedUnits(unitId);
  }

  void _addSingleMobileNumber(String? memberMobileNo) {
    if (memberMobileNo != null && memberMobileNo.isNotEmpty) {
      if (!selectedMobileNumbers.contains(memberMobileNo)) {
        selectedMobileNumbers.add(memberMobileNo); // ✅ Only this mobile number
      }
    }
  }

  void _removeMobileNumber(String? memberMobileNo) {
    if (memberMobileNo != null && memberMobileNo.isNotEmpty) {
      selectedMobileNumbers.remove(memberMobileNo); // ✅ Remove only this mobile
    }
  }

  void _addSingleMemberId(dynamic memberId) {
    // Ensure only this member ID is added
    if (memberId != null) {
      final idList = memberId.toString().split(',').map((id) => id.trim());
      for (final id in idList) {
        if (id.isNotEmpty) {
          try {
            int parsedId = int.parse(id);
            if (!selectedMemberIds.contains(parsedId)) {
              selectedMemberIds.add(parsedId); // ✅ Only this ID
            }
          } catch (e) {
            log("Error parsing member ID: $id, Error: $e");
          }
        }
      }
    }
  }

  void _removeMemberId(dynamic memberId) {
    if (memberId != null) {
      final idList = memberId.toString().split(',').map((id) => id.trim());
      for (final id in idList) {
        if (id.isNotEmpty) {
          try {
            int parsedId = int.parse(id);
            selectedMemberIds.remove(parsedId); // ✅ Remove only this ID
          } catch (e) {
            log("Error removing member ID: $id, Error: $e");
          }
        }
      }
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

  bool _isCheckedIn = false;
  bool selectedMemberSelectionLoading = false;

  @override
  Widget build(BuildContext context) {
    log("widget.selfcheckinFlow ${widget.selfcheckinFlow}");
    return WillPopScope(
      onWillPop: () async {
        if (widget.searchedVisitor != null) {
          Navigator.pop(context);
          return false; // Prevent default back navigation.
        } else {
          widget.selfcheckinFlow
              ? Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const SelfHomeView()),
                  (Route<dynamic> route) => false,
                )
              : Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const GateDashboardView()),
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
                                                            SizedBox(
                                                              width: MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .width *
                                                                  0.48,
                                                              child: Text(
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
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
                                                            ),
                                                          ],
                                                        ),
                                                        ElevatedButton.icon(
                                                          style: ButtonStyle(
                                                            foregroundColor:
                                                                WidgetStateProperty
                                                                    .all<Color>(
                                                              const Color(
                                                                  0xFF7D7C7C),
                                                            ),
                                                            backgroundColor:
                                                                WidgetStateProperty
                                                                    .all<Color>(
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .surface,
                                                            ),
                                                            elevation:
                                                                WidgetStateProperty
                                                                    .resolveWith<
                                                                        double>(
                                                              (Set<WidgetState>
                                                                      states) =>
                                                                  states.contains(
                                                                          WidgetState
                                                                              .pressed)
                                                                      ? 8
                                                                      : 0,
                                                            ),
                                                            shape: WidgetStateProperty
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
                                                                WidgetStateProperty
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
                                    visitor_purpose_Category_name:
                                        widget.purposeCategory.categoryName,
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
                                  myFluttertoast(
                                      msg: "Visitor checked in successfully");
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
                                    myFluttertoast(
                                      msg:
                                          "Error during check-in. Please try again.",
                                      backgroundColor: Colors.red,
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

  // Selection Submission Methods
  Future<void> _handleSelectionSubmit(Set<String> selectedMembers) async {
    selectedMemberSelectionLoading = true;
    await deleteImage();
    Navigator.pop(context);
    log("Handling selection submit...");
    await saveMemberAndUnitToPrefs(selectedMembers, selectedUnits);

    try {
      final visitorLogData = await _prepareVisitorLogData();

      if (selectedMembers.length == 1) {
        if (_membersApproval == true) {
          await _handleSingleMemberFlow(visitorLogData);
        } else {
          await _handleDirectApproval(visitorLogData);
        }
      } else {
        // Multi Member → Direct Check-in → Show Dialog
        await _handleMultiMemberFlow(visitorLogData);
      }
    } catch (e) {
      log("❌ Error in _handleSelectionSubmit: $e");
      _showErrorSnackbar("Error processing selection");
    }
    Future.delayed(const Duration(seconds: 1), () {
      selectedMemberSelectionLoading = false;
      setState(() {});
    });
  }

  Future<void> _handleDirectApproval(VisitorLog visitorLogData) async {
    try {
      // if (!_isCheckedIn) {
      await remoteDataSource.checkIn(visitorLogData, statusallowed = true);
      //   _isCheckedIn = true;
      // }
      widget.selfcheckinFlow
          ? Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SelfProfileView(
                  visitor: widget.visitor,
                  unitList: selectedBuildingUnits,

                  // status: 0,
                  // visitor: widget.visitor,
                  // unitList: selectedBuildingUnits,
                  visitorLog: visitorLogData,
                  // logID: logID,
                ),
              ),
            )
          : await _allowByGatekeeper(visitorLogData);
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => RequestPermissionPage2(
                  // status: 0,
                  visitor: widget.visitor,
                  visitorLog: visitorLogData,
                )),
      );
    } catch (e) {
      log("❌ Error in _handleDirectApproval: $e");
      _showErrorSnackbar("Error during gatekeeper approval.");
    }
  }

  Future<void> _allowByGatekeeper(VisitorLog visitorLogData) async {
    try {
      final response = await Dio().patch(
        '${ApiUrls.gateBaseUrl}/visitor/visitorLog/${widget.visitor.id}',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: jsonEncode({
          "allow_status": "allowed_by_gatekeeper",
        }),
      );

      if (response.statusCode == 200) {
        log("✅ Visitor allowed by Gatekeeper successfully");
        // _showSuccessSnackBar("Visitor allowed by Gatekeeper.");
        await _showApprovedDialog(context, visitorLogData, onSuccess: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const GateDashboardView()),
          );
        });
      } else {
        log("❌ Failed to allow visitor by Gatekeeper: ${response.statusMessage}");
        // _showErrorSnackBar("Error allowing visitor. Try again.");
      }
    } catch (e) {
      log("❌ Error in _allowByGatekeeper: $e");
      void showErrorSnackBar(String message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }

      // showErrorSnackBar("Failed to allow visitor.");
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _handleSingleMemberFlow(VisitorLog visitorLogData) async {
    try {
      if (!_isCheckedIn) {
        await remoteDataSource.checkIn(visitorLogData, statusallowed = true);
        _isCheckedIn = true;
      }

      final userId = selectedUserIds.first;
      final selectedMobileNumbers = await _getSelectedMobileNumbers();
      final requestData =
          await _prepareRequestData(userId, selectedMobileNumbers);

      log("✅ Sending FCM notification after Check-in...");

      // Send WebSocket event
      if (socketService.socket != null && socketService.socket!.connected) {
        socketService.socket!.emit("sendFcmNotification", requestData);
      }

      // Send FCM API request
      final apiResponse = Dio().post(
        '${ApiUrls.gateBaseUrl}/visitor/sendFcmNotification',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: requestData,
      );
      log("requestData: $requestData");

      // Listen for WebSocket response
      socketService.socket!.on("fcmResponse", (responseData) async {
        log("📩 WebSocket Response Received: $responseData");
        await _handleFcmResponse(responseData, visitorLogData);
      });

      // Handle API FCM response (fallback if WebSocket fails)
      final response = await apiResponse;
      if (response.statusCode == 200) {
        log("✅ API Response Received: ${response.data}");
        await _handleFcmResponse(response.data, visitorLogData);
      } else {
        _showErrorSnackbar("Failed to send notification. Try again.");
      }
    } catch (e) {
      log("❌ Error in _handleSingleMemberFlow: $e");
      _showErrorSnackbar("Error sending FCM notification.");
    }
  }

  Future<void> _handleFcmResponse(
      dynamic responseData, VisitorLog visitorLogData) async {
    final message = responseData["message"];
    final prefs = await SharedPreferences.getInstance();
    final logID = prefs.getString("visitor_log");
    if (message == "Visitor is always_allowed") {
      widget.selfcheckinFlow
          ? Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SelfProfileView(
                  visitor: widget.visitor,
                  unitList: selectedBuildingUnits,

                  // status: 0,
                  // visitor: widget.visitor,
                  // unitList: selectedBuildingUnits,
                  visitorLog: visitorLogData,
                  // logID: logID,
                ),
              ),
            )
          : Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RequestPermissionPage2(
                  visitor: widget.visitor,
                  unitList: selectedBuildingUnits,
                  visitorLog: visitorLogData,
                  logID: logID,
                ),
              ),
            );
    } else {
      final prefs = await SharedPreferences.getInstance();
      final logID = prefs.getString("visitor_log");
      log("selfcheckinFlow: ${widget.selfcheckinFlow}");
      visitorLogData.visitor?.mobile = widget.visitor.mobile;
      widget.selfcheckinFlow
          ? Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SelfProfileView(
                  visitor: widget.visitor,
                  unitList: selectedBuildingUnits,

                  // status: 0,
                  // visitor: widget.visitor,
                  // unitList: selectedBuildingUnits,
                  visitorLog: visitorLogData,
                  // logID: logID,
                ),
              ),
            )
          : Navigator.push(
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

  Future<void> _handleMultiMemberFlow(VisitorLog visitorLogData) async {
    try {
      if (!_isCheckedIn) {
        await remoteDataSource.checkIn(visitorLogData, statusallowed = true);
        _isCheckedIn = true;
      }

      widget.selfcheckinFlow
          ? Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SelfProfileView(
                  visitor: widget.visitor,
                  unitList: selectedBuildingUnits,
                  visitorLog: visitorLogData,
                ),
              ),
            )
          : await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => RequestPermissionPage2(
                        visitor: widget.visitor,
                        visitorLog: visitorLogData,
                      )),
            );
    } catch (e) {
      log("❌ Error in _handleMultiMemberFlow: $e");
      _showErrorSnackbar("Error processing multi-member check-in.");
    }
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
                                  context, data, setState, onSuccess);
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

      await _allowByGatekeeper(data);

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
    myFluttertoast(
      msg: message,
      backgroundColor: Colors.red,
    );
  }

  Future<VisitorLog> _prepareVisitorLogData() async {
    final prefs = await SharedPreferences.getInstance();

    List<int> unitIds = [];
    unitIds = formattedMemberDetails
        .map((member) => member['unit_id'])
        .where((id) => id != null)
        .map((id) => int.parse(id.toString()))
        .toList();

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
      visitor_id: int.parse(widget.visitor.id.toString()),
      visitor_purpose_category_id: widget.purposeCategory.categoryId ??
          int.parse(widget.purposeCategoryId.toString()),
      visitor_purpose_Category_name: widget.purposeCategory.categoryName,
      purpose_sub_category_name:
          widget.purposeCategory.subCategories?.first.subCategoryName,
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

  Future<List<String>> _getSelectedMobileNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMobileNumbersJson =
        prefs.getString('selected_member_mobile_numbers') ?? '[]';
    selectedgate = prefs.getString('selected_gate');
    final cleanedJson =
        savedMobileNumbersJson.trim().replaceAll(RegExp(r'^,+|,+$'), '');
    return cleanedJson.split(',').where((number) => number.isNotEmpty).toList();
  }

  List<String> getAllSelectedMobileNumbers() {
    return formattedMemberDetails
        .map((e) => e['mobile_number'].toString())
        .where((mobile) => mobile.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<Map<String, dynamic>> _prepareRequestData(
    String userId,
    List<String> savedMobileNumbers,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final visitorLogId = prefs.getString("visitor_log") ?? "";
    final String? visitorId = prefs.getString('visitorId');

    final mobileNumbers = getAllSelectedMobileNumbers();

    log("Visitor Log ID: $visitorLogId");
    log("Member mobile numbers from selection $mobileNumbers");

    return {
      "self_check_in": widget.selfcheckinFlow.toString() ?? "false",
      'company_id': companyId.toString(),
      'name': widget.guestname,
      'mobile': widget.mobileNumber,
      'purpose': widget.purposeCategory.categoryName.toLowerCase(),
      'in_time': formattedInTime,
      'user_id': (int.tryParse(userId) == null || int.tryParse(userId) == 0)
          ? "234567"
          : int.parse(userId).toString(),
      'visitor_count':
          widget.guestCount != null ? widget.guestCount.toString() : "1",
      'member_mobile_number':
          mobileNumbers.isNotEmpty ? mobileNumbers.first : "",
      'visitor_id': widget.visitor.id?.toString() ??
          widget.searchedVisitor?.id?.toString() ??
          '',
      'purpose_category': widget.purposeCategory.categoryId.toString() == "3"
          ? "delivery"
          : widget.purposeCategory.categoryId.toString(),
      'visitor_log_id': visitorLogId,
      'coming_from': widget.comingFrom?.toString() ?? "delivery",
      'member_id': selectedMemberIds.isNotEmpty
          ? selectedMemberIds.first.toString()
          : "232",
      'company_name': companyName ?? "",
      "file": widget.visitor.visitor_image ?? ""
    };
  }

  bool _isButtonDisabled = false;

  bool statusallowed = false;
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
