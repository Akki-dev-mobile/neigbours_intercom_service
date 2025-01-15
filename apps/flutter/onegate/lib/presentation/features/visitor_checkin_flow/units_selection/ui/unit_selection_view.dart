import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:common_widgets/common_widgets.dart';
import 'package:dart_amqp/dart_amqp.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/entities/gate/gate.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/visitor_Settings_provider.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_entry/ui/visitor_in_entry.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get_it/get_it.dart';
// import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:onegate_client/onegate_client.dart' as c;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLogMapper.dart';

class UnitSelectionView extends StatefulWidget {
  c.Visitor? searchedVisitor;
  final c.Visitor visitor;
  final c.PurposeCategory purposeCategory;
  final String? comingFrom;
  final int? guestCount;
  final int? visitorId;
  final int? companyId;
  final String guestname;
  final String mobileNumber;
  final String? visitorNumber;

  UnitSelectionView(
    c.Visitor? searchedVisitor, {
    Key? key,
    required this.visitor,
    required this.purposeCategory,
    this.comingFrom,
    this.guestCount,
    this.companyId,
    this.visitorId,
    required this.guestname,
    required this.mobileNumber,
    this.visitorNumber,
  }) : super(key: key);

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
  // State Data
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
    _initializeFuture = _initializeMembers(); // Initialize the Future once
    log("${selectedUnits} here is this");
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

  void _showSelectedMembersBottomSheet(Set<String> selectedMember) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ValueListenableBuilder<Set<String>>(
        valueListenable: _selectedMembersNotifier,
        builder: (context, updatedSelectedMember, _) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[200]!,
                      width: 1, // Border thickness
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected Members (${updatedSelectedMember.length})',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: updatedSelectedMember.length,
                  itemBuilder: (context, index) {
                    final member = updatedSelectedMember.elementAt(index);
                    return ListTile(
                      title: Text(member),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          final updatedMembers =
                              Set<String>.from(_selectedMembersNotifier.value);
                          updatedMembers.remove(member);
                          _selectedMembersNotifier.value = updatedMembers;
                          if (updatedMembers.isEmpty) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: CustomLargeBtn(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleSelectionSubmit(updatedSelectedMember);
                      },
                      text: 'Allow'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(Set<String> selectedMember) {
    return GestureDetector(
      onTap: () => _showSelectedMembersBottomSheet(selectedMember),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.people),
                const SizedBox(width: 8),
                Text(
                  selectedMember.length > 1
                      ? '${selectedMember.length} Selected'
                      : selectedMember.first,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white),
                ),
              ],
            ),
            const Icon(Icons.keyboard_arrow_up),
          ],
        ),
      ),
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
              icon: Icon(
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
            Icons.groups_outlined, // Google Material Icon
            size: 60,
            color: Colors.grey[400], // Subtle grey color for the icon
          ),
          const SizedBox(height: 16), // Spacing between icon and text
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

  // Selection Handling Methods
  List<Map<String, dynamic>> formattedMemberDetails = [];

  // Update the _handleMemberSelection method
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
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Header with back button and title
                  Container(
                    // padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back),
                          onPressed: () {
                            if (widget.searchedVisitor != null) {
                              Navigator.pop(context);
                            } else {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => GateDashboardView()),
                                (Route<dynamic> route) => false,
                              );
                            }
                          },
                        ),
                        Text(
                          'Select Units/Members',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  // Main content
                  Expanded(
                    child: FutureBuilder<void>(
                      future: _initializeFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  "Loading Units and Members...",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: TextStyle(color: Colors.red, fontSize: 16),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 0.0, horizontal: 10),
                              child: _buildSearchField(context),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 40.0),
                                child: _buildMemberList(context),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
              // Bottom bar
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
                    return Container(
                      color: Colors.black,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            elevation: 8,
                            color: Colors.black,
                            child: InkWell(
                              onTap: () => _showSelectedMembersBottomSheet(
                                  selectedMember),
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: 20,
                                  right: 20,
                                  top: 16,
                                  bottom: MediaQuery.of(context)
                                              .viewInsets
                                              .bottom >
                                          0
                                      ? MediaQuery.of(context).viewInsets.bottom
                                      : 16 +
                                          MediaQuery.of(context).padding.bottom,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.people,
                                            color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text(
                                            selectedMember.length > 1
                                                ? '${selectedMember.length} Selected'
                                                : selectedMember.first,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                    color: Colors.white)),
                                      ],
                                    ),
                                    const Icon(
                                      Icons.keyboard_arrow_up,
                                      color: Colors.white,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: Column(
        children: [
          _buildSearchField(context),
          Expanded(child: _buildMemberList(context)),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _selectedMembersNotifier,
      builder: (context, selectedMember, child) {
        if (selectedMembers.isEmpty && selectedMember.isEmpty) {
          return const SizedBox();
        }
        return _buildSelectionBar(selectedMember);
      },
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

    // Validate the selection
    if (!_validateSelection(selectedMember)) return;

    // Prepare the visitor log data
    final visitorLogData = await _prepareVisitorLogData();

    if (_membersApproval = true) {
      // If membersApproval is true, send FCM notification
      log("Members approval is required. Sending notification...");
      await _processSelectionSubmission(selectedMember, visitorLogData);
    } else {
      // If membersApproval is false, directly show the approval dialog
      log("Members approval is not required. Directly showing approval dialog...");
      await _showApprovedDialog(context, visitorLogData);
    }
  }

  bool _validateSelection(Set<String> selectedMember) {
    if (selectedMember.length != 1 || selectedUnits.length != 1) {
      _handleInvalidSelection();
      return false;
    }
    return true;
  }

// Update the _prepareVisitorLogData method
  Future<c.VisitorLog> _prepareVisitorLogData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? visitorId = prefs.getString('visitorId');
    final companyDetails = await gateStorage.getSocietyDetails();
    final companyName = companyDetails['societyName'];
    final selectedGateName = prefs.getString('selected_gate');

    // Extract unit IDs from formattedMemberDetails
    List<int> unitIds = [];
    if (formattedMemberDetails != null && formattedMemberDetails is List) {
      unitIds = formattedMemberDetails
          .map((member) => member['unit_id'])
          .where((id) => id != null)
          .map((id) => int.parse(id.toString()))
          .toList();
    }

    // Map unit IDs to BuildingAssignment objects
    List<c.BuildingAssignment> buildingAssignments = unitIds.map((unitId) {
      return c.BuildingAssignment(
        id: null,
        visitor_id: widget.visitor.id,
        visitor_log_id: null,
        company_id: int.parse(companyId.toString()),
        building_id: 0,
        unit_id: [unitId.toString()],
      );
    }).toList();

    // Save formattedMemberDetails to SharedPreferences
    try {
      final String memberDetailsJson = json.encode(formattedMemberDetails);
      await prefs.setString('member_details', memberDetailsJson);
      print('Successfully saved member details: $memberDetailsJson');
    } catch (e) {
      print('Error saving member details: $e');
    }

    return c.VisitorLog(
      visitor_id: widget.visitor.id ?? 0,
      visitor_purpose_category_id: widget.purposeCategory.id ?? 1,
      visitor_purpose_sub_category_id: null,
      visitor_count: widget.guestCount ?? 0,
      visitor_check_in: DateTime.parse(formattedInTime),
      visitor_card_number: widget.visitorNumber,
      visitor_coming_from: widget.comingFrom,
      visitor_card_id: null,
      company_id: int.parse(companyId.toString()),
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

    // Map unit IDs to BuildingAssignment objects
    List<c.BuildingAssignment> buildingAssignments = unitIds.map((unitId) {
      return c.BuildingAssignment(
        id: null,
        visitor_id: widget.visitor.id,
        visitor_log_id: null,
        company_id: int.parse(companyId.toString()),
        building_id: 0,
        unit_id: [unitId.toString()],
      );
    }).toList();

    // Load the selected gate from SharedPreferences
    final selectedGateName = prefs.getString('selected_gate');
    final visitorLogData = c.VisitorLog(
        visitor_id: widget.visitor.id ?? 0,
        visitor_purpose_category_id: widget.purposeCategory.id ?? 1,
        visitor_purpose_sub_category_id: null,
        visitor_count: widget.guestCount ?? 0,
        visitor_check_in: DateTime.parse(formattedInTime),
        visitor_card_number: widget.visitorNumber,
        visitor_coming_from: widget.comingFrom,
        visitor_building_assignment: buildingAssignments,
        visitor_card_id: null,
        company_id: int.parse(companyId.toString()),
        is_checked_out: false);
    final String memberDetailsJson = json.encode(formattedMemberDetails);
    await prefs.setString('member_details', memberDetailsJson);
    await _showApprovedDialog(context, visitorLogData);
  }

  Future<void> _processSelectionSubmission(
      Set<String> selectedMember, c.VisitorLog visitorLogData) async {
    final userId = selectedUserIds.first;
    final selectedMobileNumbers = await _getSelectedMobileNumbers();
    final requestData = _prepareRequestData(userId, selectedMobileNumbers);

    try {
      await _sendFcmNotification(requestData, visitorLogData);
    } catch (e) {
      _handleSubmissionError(e, visitorLogData);
    }
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

  Map<String, String> _prepareRequestData(
      String userId, List<String> savedMobileNumbers) {
    return {
      'company_id': companyId.toString(),
      'name': widget.guestname,
      'mobile': widget.mobileNumber,
      'purpose': "meeting",
      'in_time': formattedInTime,
      'user_id': (int.tryParse(userId) ?? 5243243).toString(),
      'visitor_count': widget.guestCount.toString(),
      "member_mobile_number": "918452060059",
      "visitor_id": widget.visitorId?.toString() ?? "",
      "purpose_category": widget.purposeCategory.id?.toString() ?? "",
      'purpose_details': "zomato",
      'coming_from': widget.comingFrom ?? "Unknown",
      "member_id": "${selectedMemberIds.first}",
      "company_name": companyName ?? "",
    };
  }

  Future<void> _sendFcmNotification(
      Map<String, String> requestData, c.VisitorLog visitorLogData) async {
    try {
      final response = await Dio().post(
        'https://gateapi.cubeone.in/api/visitor/sendFcmNotification',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: requestData,
      );

      if (response.statusCode == 200) {
        log("FCM notification sent successfully: ${response.data}");
        Fluttertoast.showToast(
          msg: "Notification Sent",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        // await Navigator.push(context,
        //     MaterialPageRoute(builder: (context) => GateDashboardView()));
        bool isWaitingForApproval = false;
        setState(() => isWaitingForApproval = true);
        await _notificationSent(context, visitorLogData);
      }
    } on DioError catch (e) {
      _handleDioError(e, visitorLogData);
    }
  }

  void _handleDioError(DioError e, c.VisitorLog visitorLogData) async {
    if (e.response?.statusCode == 400) {

      await _notificationSent(context, visitorLogData);
    } else {
      log("Error during FCM notification: ${e.response?.statusCode} - ${e.response?.data}");
    }
  }

  void _handleSubmissionError(
      dynamic error, c.VisitorLog visitorLogData) async {
    log("Unexpected error during submission: $error");
    await _showApprovedDialog(context, visitorLogData);
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

  Future<void> _showApprovedDialog(
      BuildContext context, c.VisitorLog data) async {
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
                        ? const Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                "please wait checkin",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          )
                        : CustomLargeBtn(
                            onPressed: () async {
                              if (_isButtonDisabled) return;

                              setState(() {
                                _isLoading = true;
                                _isButtonDisabled = true;
                              });

                              try {
                                await remoteDataSource.checkIn(data);

                                if (savedMemberUnitDetails.isNotEmpty) {
                                  log('Sending visitor log details: ${jsonEncode([
                                        savedMemberUnitDetails
                                      ])}');

                                  Navigator.pop(context);
                                  await Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const GateDashboardView(),
                                    ),
                                  );
                                } else {
                                  log('Error: savedMemberUnitDetails is empty');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Error: Missing member details'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                log('Error in approved dialog: $e');
                                setState(() {
                                  _isLoading = false;
                                  _isButtonDisabled = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Error processing approval'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
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

  Future<void> _notificationSent(BuildContext context, c.VisitorLog data) async {
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
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            Theme.of(context).primaryColor.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : null,
                        color: _isButtonDisabled ? Colors.grey[300] : null,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: !_isButtonDisabled
                            ? [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withOpacity(0.3),
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
                              builder: (context) => const GateDashboardView(),
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
                              color: _isButtonDisabled ? Colors.grey[500] : Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Check Approval Status",
                              style: TextStyle(
                                color: _isButtonDisabled ? Colors.grey[500] : Colors.white,
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
