import 'dart:convert';
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:common_widgets/common_widgets.dart';
import 'package:dart_amqp/dart_amqp.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLogMapper.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get_it/get_it.dart'; // import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:onegate_client/onegate_client.dart' as c;
import 'package:shared_preferences/shared_preferences.dart';

class UnitSelectionView extends StatefulWidget {
  final VisitorMapper visitor;
  final c.PurposeCategory purposeCategory;
  final String? comingFrom;
  final int? guestCount;
  final int? visitorId;
  final int? companyId;
  final String guestname;
  final String mobileNumber;
  final String? visitorNumber;

  const UnitSelectionView({
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
  List<dynamic> _allMembers = [];
  int? companyId;
  bool isLoading = true;
  Map<String, dynamic> savedMemberUnitDetails = {};
  Set<String> selectedUserIds = {};
  List<int> selectedMemberIds = [];
  List<String> selectedBuildingUnits = [];
  String formattedInTime =
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
  String? approvalStatus = "Waiting for approval...";
  int? selectedUnit;
  int? selectedMember;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterMembers);
    _fetchCompanyId();
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
    setState(() {});
  }

  Future<List<dynamic>> getMember() async {
    try {
      final response = await _dio.get(
        'https://societybackend.cubeone.in/api/admin/member/list',
        queryParameters: {
          'company_id': companyId.toString(),
          'unit_id': null,
          'current_tab': 'approved'
        },
      );
      return response.data['data'];
    } catch (e) {
      log('Error fetching members: $e');
      rethrow;
    }
  }

  Future<void> _initializeMembers() async {
    final members = await getMember();
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

  // Storage Methods
  Future<void> saveMemberAndUnitToPrefs(
      Set<String> memberDetails, Set<int> unitIDs) async {
    savedMemberUnitDetails = {
      'member_details': memberDetails.toList(),
      'unit_ids': unitIDs.whereType<int>().toList(),
      'member_ids': selectedMemberIds.toList(),
      'building_unit': selectedBuildingUnits.toList(),
    };
    log('Saved member and unit details: ${jsonEncode(savedMemberUnitDetails)}');
  }

  // UI Methods
  Widget _buildSearchField(BuildContext context) {
    return CustomForm.textField(
      'Search Units/Members ',
      titleColor: Theme.of(context).colorScheme.onSurface,
      hintColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
      hintText: 'Search Units/Members',
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
                color: Theme.of(context).colorScheme.onSurface,
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
      child: Text(
        'No Members Found.\nSearch members by their name or flat',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey[600],
        ),
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
    } else {
      updatedMembers.add(firstName);
      selectedUserIds.add(userId);
      _addMemberIds(memberId);
      selectedBuildingUnits.add(buildingUnit);
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
    return MyScrollView(
      isScrollable: false,
      pageTitle: 'Select Units/Members',
      pageBody: FutureBuilder<void>(
        future: _initializeMembers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 250,
                  ),
                  Center(
                      child: CircularProgressIndicator(
                    color: Colors.grey,
                  )),
                  SizedBox(height: 16),
                  Text(
                    "Loading Units and Members...",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
          return _buildMainContent();
        },
      ),
      bottomNavigationBar: _buildFloatingActionButton(context),
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

  Widget _buildFloatingActionButton(
    BuildContext context,
  ) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _selectedMembersNotifier,
      builder: (context, selectedMembers, child) {
        if (selectedMembers.isEmpty) {
          return const SizedBox(); // Hide FAB when no members are selected
        }

        return GestureDetector(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            color: Theme.of(context).colorScheme.onSurface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.5,
                  child: Text(
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    selectedMembers.length > 1
                        ? "${selectedMembers.first} +${selectedMembers.length - 1}"
                        : selectedMembers.first,
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.surface,
                        ),
                  ),
                ),
                Container(
                  height: MediaQuery.of(context).size.height * 0.08,
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: selectedMembers.isNotEmpty &&
                          selectedMembers.length < 2
                      ? Directionality(
                          textDirection: ui.TextDirection.rtl,
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.check,
                              size: 15,
                            ),
                            label: Text(
                              selectedMembers.length < 2 ? "Allow" : "Next",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                            ),
                            onPressed: () async {
                              log("FloatingActionButtonunitId Selected Member: $selectedMembers, Selected Unit: $selectedUnit");

                              if (selectedUnits != null ||
                                  selectedMember != null) {
                                log("Selected Unit: $selectedUnits");
                                log("Selected Member: $selectedMember");

                                String? userId;
                                if (selectedUnits.isNotEmpty) {
                                  userId = selectedUnits.first.toString();
                                } else if (selectedMembers.isNotEmpty) {
                                  userId = _allMembers
                                      .firstWhere(
                                        (member) => selectedMembers.contains(
                                          member['member_name'],
                                        ),
                                      )['id']
                                      .toString();
                                }

                                List<int> memberIds = _allMembers
                                    .where((member) => selectedMembers
                                        .contains(member['member_name']))
                                    .map<int>(
                                        (member) => member['member_id'] as int)
                                    .toList();

                                log("Member IDs List: $memberIds");

                                log("Post Selection:::");
                                // await _handleSelectionSubmit(selectedMembers);
                              } else {
                                log("No selection made");
                              }
                            },
                            style: ButtonStyle(
                              foregroundColor: MaterialStateProperty.all<Color>(
                                const Color(0xFF7D7C7C),
                              ),
                              backgroundColor: MaterialStateProperty.all<Color>(
                                Theme.of(context).colorScheme.surface,
                              ),
                              elevation:
                                  MaterialStateProperty.resolveWith<double>(
                                (Set<MaterialState> states) {
                                  if (states.contains(MaterialState.pressed)) {
                                    return 8;
                                  }
                                  return 0;
                                },
                              ),
                              shape: MaterialStateProperty.all<
                                  RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              padding:
                                  MaterialStateProperty.all<EdgeInsetsGeometry>(
                                const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          height: MediaQuery.of(context).size.height * 0.08,
                          width: MediaQuery.of(context).size.width * 0.4,
                          child: Directionality(
                            textDirection: ui.TextDirection.rtl,
                            child: ElevatedButton.icon(
                              style: ButtonStyle(
                                foregroundColor:
                                    MaterialStateProperty.all<Color>(
                                  const Color(0xFF7D7C7C),
                                ),
                                backgroundColor:
                                    MaterialStateProperty.all<Color>(
                                  Theme.of(context).colorScheme.surface,
                                ),
                                elevation:
                                    MaterialStateProperty.resolveWith<double>(
                                  (Set<MaterialState> states) {
                                    if (states
                                        .contains(MaterialState.pressed)) {
                                      return 8;
                                    }
                                    return 0;
                                  },
                                ),
                                shape: MaterialStateProperty.all<
                                    RoundedRectangleBorder>(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                padding: MaterialStateProperty.all<
                                    EdgeInsetsGeometry>(
                                  const EdgeInsets.symmetric(
                                    horizontal: 36,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                              onPressed: () async {
                                showModalBottomSheet(
                                  context: context,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20)),
                                  ),
                                  isDismissible: false,
                                  builder: (context) {
                                    return ValueListenableBuilder<Set<String>>(
                                      valueListenable: _selectedMembersNotifier,
                                      builder:
                                          (context, selectedMembers, child) {
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 10,
                                              ),
                                              color: Colors.black,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceEvenly,
                                                children: [
                                                  Text(
                                                    "Selected Members",
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleLarge
                                                        ?.copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .background,
                                                        ),
                                                  ),
                                                  Container(
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.08,
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.4,
                                                    child: Directionality(
                                                      textDirection:
                                                          ui.TextDirection.rtl,
                                                      child:
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
                                                                states) {
                                                              if (states.contains(
                                                                  MaterialState
                                                                      .pressed)) {
                                                                return 8;
                                                              }
                                                              return 0;
                                                            },
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
                                                              horizontal: 16,
                                                              vertical: 10,
                                                            ),
                                                          ),
                                                        ),
                                                        onPressed: () async {
                                                          log("FloatingActionButtonunitId Selected Member: $selectedMembers, Selected Unit: $selectedUnit");

                                                          if (selectedUnits !=
                                                                  null ||
                                                              selectedMember !=
                                                                  null) {
                                                            log("Selected Unit: $selectedUnits");
                                                            log("Selected Member: $selectedMember");

                                                            String? userId;
                                                            if (selectedUnits
                                                                .isNotEmpty) {
                                                              userId =
                                                                  selectedUnits
                                                                      .first
                                                                      .toString();
                                                            } else if (selectedMembers
                                                                .isNotEmpty) {
                                                              userId = _allMembers
                                                                  .firstWhere(
                                                                    (member) =>
                                                                        selectedMembers
                                                                            .contains(
                                                                      member[
                                                                          'member_name'],
                                                                    ),
                                                                  )['id']
                                                                  .toString();
                                                            }

                                                            List<int> memberIds = _allMembers
                                                                .where((member) =>
                                                                    selectedMembers
                                                                        .contains(
                                                                            member[
                                                                                'member_name']))
                                                                .map<int>((member) =>
                                                                    member['member_id']
                                                                        as int)
                                                                .toList();

                                                            log("Member IDs List: $memberIds");

                                                            log("Post Selection:::");
                                                            await _handleSelectionSubmit(
                                                                selectedMembers);
                                                          } else {
                                                            log("No selection made");
                                                          }
                                                        },
                                                        icon: selectedMembers
                                                                    .length >
                                                                1
                                                            ? const Icon(
                                                                Icons.check,
                                                                size: 15,
                                                              ) // Icon for "Allow"
                                                            : const Icon(
                                                                Icons
                                                                    .navigate_next,
                                                                size: 18),
                                                        label: Text(
                                                          selectedMembers
                                                                      .length >
                                                                  1
                                                              ? "Allow"
                                                              : "Next",
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodyMedium!
                                                                  .copyWith(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .onSurface,
                                                                  ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            if (selectedMembers.isEmpty)
                                              const Center(
                                                child: Text(
                                                  "No members selected.",
                                                  style: TextStyle(
                                                      color: Colors.grey),
                                                ),
                                              ),
                                            Expanded(
                                              child: ListView(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        0, 12, 0, 10),
                                                children: [
                                                  ...selectedMembers.map(
                                                    (member) => ListTile(
                                                      leading: const Icon(
                                                          Icons.person),
                                                      title: Text(
                                                        member,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium,
                                                      ),
                                                      trailing: IconButton(
                                                        icon: const Icon(
                                                            Icons.close,
                                                            color: Colors.red),
                                                        onPressed: () {
                                                          // Remove member from the notifier
                                                          final updatedMembers =
                                                              Set<String>.from(
                                                                  selectedMembers);
                                                          updatedMembers
                                                              .remove(member);

                                                          // Update the notifier value directly to trigger the rebuild
                                                          _selectedMembersNotifier
                                                                  .value =
                                                              updatedMembers;

                                                          // Close the bottom sheet if no members remain
                                                          if (updatedMembers
                                                              .isEmpty) {
                                                            Navigator.pop(
                                                                context);
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                              icon: selectedMembers.length > 1
                                  ? const Icon(
                                      Icons.check,
                                      size: 15,
                                    ) // Icon for "Allow"
                                  : const Icon(Icons.navigate_next, size: 18),
                              label: Text(
                                selectedMembers.length > 1 ? "View" : "Next",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          onTap: () {
            FocusScope.of(context).requestFocus(
              FocusNode(),
            );

            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              isDismissible: true,
              builder: (context) {
                return _buildBottomSheet(context);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _selectedMembersNotifier,
      builder: (context, selectedMembers, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20.0),
                  topRight: Radius.circular(20.0),
                ),
                color: Theme.of(context).colorScheme.onSurface,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    "Selected Members",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.surface,
                        ),
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.08,
                    width: MediaQuery.of(context).size.width * 0.4,
                    child: Directionality(
                      textDirection: ui.TextDirection.rtl,
                      child: ElevatedButton.icon(
                        style: ButtonStyle(
                          foregroundColor: MaterialStateProperty.all<Color>(
                            const Color(0xFF7D7C7C),
                          ),
                          backgroundColor: MaterialStateProperty.all<Color>(
                            Theme.of(context).colorScheme.surface,
                          ),
                          elevation: MaterialStateProperty.resolveWith<double>(
                            (Set<MaterialState> states) {
                              if (states.contains(MaterialState.pressed)) {
                                return 8;
                              }
                              return 0;
                            },
                          ),
                          shape:
                              MaterialStateProperty.all<RoundedRectangleBorder>(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          padding:
                              MaterialStateProperty.all<EdgeInsetsGeometry>(
                            const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                        onPressed: () async {
                          log("FloatingActionButtonunitId Selected Member: $selectedMembers, Selected Unit: $selectedUnit");

                          if (selectedUnits != null || selectedMember != null) {
                            log("Selected Unit: $selectedUnits");
                            log("Selected Member: $selectedMember");

                            String? userId;
                            if (selectedUnits.isNotEmpty) {
                              userId = selectedUnits.first.toString();
                            } else if (selectedMembers.isNotEmpty) {
                              userId = _allMembers
                                  .firstWhere(
                                    (member) => selectedMembers.contains(
                                      member['member_name'],
                                    ),
                                  )['id']
                                  .toString();
                            }

                            List<int> memberIds = _allMembers
                                .where((member) => selectedMembers
                                    .contains(member['member_name']))
                                .map<int>(
                                    (member) => member['member_id'] as int)
                                .toList();

                            log("Member IDs List: $memberIds");

                            log("Post Selection:::");
                            await _handleSelectionSubmit(selectedMembers);
                          } else {
                            log("No selection made");
                          }
                        },
                        icon: selectedMembers.length > 1
                            ? const Icon(
                                Icons.check,
                                size: 15,
                              ) // Icon for "Allow"
                            : const Icon(Icons.navigate_next, size: 18),
                        label: Text(
                          selectedMembers.length > 1 ? "Allow" : "Next",
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            (selectedMembers.isEmpty)
                ? const Center(
                    child: Text(
                      "No members selected.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 10),
                      children: [
                        ...selectedMembers.map(
                          (member) => ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(
                              member,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                // Remove member from the notifier
                                final updatedMembers =
                                    Set<String>.from(selectedMembers);
                                updatedMembers.remove(member);

                                // Update the notifier value directly to trigger the rebuild
                                _selectedMembersNotifier.value = updatedMembers;

                                // Close the bottom sheet if no members remain
                                if (updatedMembers.isEmpty) {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
        );
      },
    );
  }

  // Widget _buildFloatingActionButton() {
  //   return ValueListenableBuilder<Set<String>>(
  //     valueListenable: _selectedMembersNotifier,
  //     builder: (context, selectedMember, child) {
  //       if (selectedMembers.isEmpty && selectedMember.isEmpty) {
  //         return const SizedBox();
  //       }
  //       return _buildSelectionBar(selectedMember);
  //     },
  //   );
  // }

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

    if (!_validateSelection(selectedMember)) return;

    final visitorLogData = await _prepareVisitorLogData();
    await _processSelectionSubmission(selectedMember, visitorLogData);
  }

  bool _validateSelection(Set<String> selectedMember) {
    if (selectedMember.length != 1 || selectedUnits.length != 1) {
      _handleInvalidSelection();
      return false;
    }
    return true;
  }

  Future<VisitorLogMapper> _prepareVisitorLogData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? visitorId = prefs.getString('visitorId');

    return VisitorLogMapper(
      visitorId: widget.visitorId ?? int.parse(visitorId!),
      visitorPurposeCategoryId: widget.purposeCategory.id ?? 1,
      visitorPurposeSubCategoryId: null,
      visitorCount: 1,
      visitorCheckIn: DateTime.parse(formattedInTime),
      visitorCheckOut: null,
      visitorCardNumber: widget.visitorNumber,
      visitorComingFrom: widget.comingFrom,
      visitorCardId: null,
      companyId: companyId!,
      isCheckedOut: false,
    );
  }

  void _handleInvalidSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final String? visitorId = prefs.getString('visitorId');

    final visitorLogData = VisitorLogMapper(
      visitorId: widget.visitorId ?? int.parse(visitorId!),
      visitorPurposeCategoryId: 1,
      visitorPurposeSubCategoryId: widget.purposeCategory.id ?? 1,
      visitorCount: 1,
      visitorCheckIn: DateTime.parse(formattedInTime),
      visitorCheckOut: null,
      visitorCardNumber: widget.visitorNumber,
      visitorComingFrom: widget.comingFrom,
      visitorCardId: null,
      companyId: companyId!,
      isCheckedOut: false,
    );

    await _showApprovedDialog(context, visitorLogData);
  }

  Future<void> _processSelectionSubmission(
      Set<String> selectedMember, VisitorLogMapper visitorLogData) async {
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
      'visitor_count': widget.guestCount?.toString() ?? "1",
      "member_mobile_number": "918452060059",
      "member_id": selectedMemberIds.first.toString(),
      "visitor_id": widget.visitorId?.toString() ?? "",
      "purpose_category": widget.purposeCategory.id?.toString() ?? "",
      'purpose_details': "zomato",
      'coming_from': widget.comingFrom ?? "Unknown",
    };
  }

  Future<void> _sendFcmNotification(
      Map<String, String> requestData, VisitorLogMapper visitorLogData) async {
    try {
      final response = await Dio().post(
        'https://gateapi.cubeone.in/api/visitor/sendFcmNotification',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: requestData,
      );

      if (response.statusCode == 200) {
        log("FCM notification sent successfully: ${response.data}");
        bool isWaitingForApproval = false;
        setState(() => isWaitingForApproval = true);
        await _showApprovedDialog(context, visitorLogData);
      }
    } on DioError catch (e) {
      _handleDioError(e, visitorLogData);
    }
  }

  void _handleDioError(DioError e, VisitorLogMapper visitorLogData) async {
    if (e.response?.statusCode == 400) {
      // Fluttertoast.showToast(
      //   msg: "Not a OneApp user",
      //   toastLength: Toast.LENGTH_SHORT,
      //   gravity: ToastGravity.BOTTOM,
      //   backgroundColor: Colors.red,
      //   textColor: Colors.white,
      // );
      await _showApprovedDialog(context, visitorLogData);
    } else {
      log("Error during FCM notification: ${e.response?.statusCode} - ${e.response?.data}");
    }
  }

  void _handleSubmissionError(
      dynamic error, VisitorLogMapper visitorLogData) async {
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
      barrierDismissible: false, // Prevent dismissing the dialog
      builder: (_) {
        return AlertDialog(
          title: const Text("Approval Status"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (approvalStatus == "Waiting for approval...")
                    const CircularProgressIndicator(
                      color: Colors.grey,
                    ),
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
                  // Clear `approvalStatus` and close the dialog
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
      // Ensure `approvalStatus` is cleared if the dialog is dismissed in other ways
      setState(() {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const GateDashboardView()));
      });
    });
  }

  Future<void> _showApprovedDialog(
      BuildContext context, VisitorLogMapper data) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
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
                  "Approved!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                CustomLargeBtn(
                  onPressed: () async {
                    try {
                      // First perform the check-in
                      await remoteDataSource.checkIn(data);

                      // Use the existing savedMemberUnitDetails which was populated earlier
                      if (savedMemberUnitDetails.isNotEmpty) {
                        // Log the data being sent
                        log('Sending visitor log details: ${jsonEncode([
                              savedMemberUnitDetails
                            ])}');

                        await remoteDataSource
                            .visitorLogDetails([savedMemberUnitDetails]);

                        // Navigate to dashboard on success
                        await Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const GateDashboardView()),
                        );
                      } else {
                        log('Error: savedMemberUnitDetails is empty');
                        // Show error toast or handle empty data case
                        Fluttertoast.showToast(
                          msg: "Error: Missing member details",
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                        );
                      }
                    } catch (e) {
                      log('Error in approved dialog: $e');
                      // Show error toast
                      Fluttertoast.showToast(
                        msg: "Error processing approval",
                        backgroundColor: Colors.red,
                        textColor: Colors.white,
                      );
                    }
                  },
                  text: "Continue",
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
