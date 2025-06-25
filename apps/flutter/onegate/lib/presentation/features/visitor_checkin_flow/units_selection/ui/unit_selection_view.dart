import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
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
  Timer? _debounceTimer;
  bool _isSearching = false;
  List<String> _buildingNames = []; // Store building names from API
  String? _selectedBuildingName; // Track selected building for filtering
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
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    // We'll handle search changes in the onChanged callback instead
    _fetchCompanyId();
    _loadVisitorSettings();
    _initializeSocketConnection();
    log("$selectedUnits here is this");
    _isLoading = true; // Set loading state before fetching members

    // Initialize members with caching
    _initializeMembers(forceRefresh: false).then((_) {
      if (mounted) {
        setState(() {
          // If we have buildings and no building is selected yet, select the first one
          if (_buildingNames.isNotEmpty && _selectedBuildingName == null) {
            _selectedBuildingName = _buildingNames[0];
            // Refresh members list with the selected building
            _initializeMembers(forceRefresh: false);
          }
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
    _debounceTimer?.cancel();
    log("Disposing UnitSelectionView with subCategoryId: ${widget.selectedSubCategoryId}");
    super.dispose();
  }

  // Cache keys
  String get _buildingCacheKey =>
      'members_cache_${_selectedBuildingName ?? "all"}';
  String get _buildingNamesCacheKey => 'building_names_cache';
  String get _cacheDateKey =>
      'members_cache_date_${_selectedBuildingName ?? "all"}';

  // Check if cache is valid (not older than 24 hours)
  Future<bool> _isCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheDate = prefs.getString(_cacheDateKey);
    if (cacheDate == null) return false;

    final cachedDateTime = DateTime.parse(cacheDate);
    final now = DateTime.now();
    final difference = now.difference(cachedDateTime);

    // Cache is valid if less than 24 hours old
    return difference.inHours < 24;
  }

  // Save members data to cache
  Future<void> _cacheMembersData(List<dynamic> members) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_buildingCacheKey, jsonEncode(members));
      await prefs.setString(_cacheDateKey, DateTime.now().toIso8601String());
      log('Members data cached for building: ${_selectedBuildingName ?? "all"}');
    } catch (e) {
      log('Error caching members data: $e');
    }
  }

  // Save building names to cache
  Future<void> _cacheBuildingNames(List<String> buildingNames) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_buildingNamesCacheKey, jsonEncode(buildingNames));
      log('Building names cached');
    } catch (e) {
      log('Error caching building names: $e');
    }
  }

  // Get cached members data
  Future<List<dynamic>?> _getCachedMembersData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_buildingCacheKey);
      if (cachedData != null) {
        return jsonDecode(cachedData) as List<dynamic>;
      }
    } catch (e) {
      log('Error retrieving cached members data: $e');
    }
    return null;
  }

  // Get cached building names
  Future<List<String>?> _getCachedBuildingNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_buildingNamesCacheKey);
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((name) => name.toString()).toList();
      }
    } catch (e) {
      log('Error retrieving cached building names: $e');
    }
    return null;
  }

  Future<void> _initializeMembers({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      // Try to get data from cache first
      final isCacheValid = await _isCacheValid();
      if (isCacheValid) {
        final cachedMembers = await _getCachedMembersData();
        if (cachedMembers != null) {
          log('Using cached members data for building: ${_selectedBuildingName ?? "all"}');
          _allMembers = cachedMembers;
          _filteredMembersNotifier.value = _allMembers;

          // If building names are not set, try to get them from cache
          if (_buildingNames.isEmpty) {
            final cachedBuildingNames = await _getCachedBuildingNames();
            if (cachedBuildingNames != null && cachedBuildingNames.isNotEmpty) {
              _buildingNames = cachedBuildingNames;
              _selectedBuildingName ??= _buildingNames[0];
              return;
            }
          } else {
            return;
          }
        }
      }
    }

    // If cache is not valid or forced refresh, fetch from API
    final response = await remoteDataSource.getMembersList(
      buildingName: _selectedBuildingName,
    );

    // Extract members list from response
    _allMembers = response['data'] ?? [];
    _filteredMembersNotifier.value = _allMembers;

    // Cache the members data
    await _cacheMembersData(_allMembers);

    // Extract building names from meta if available and not already set
    if ((_buildingNames.isEmpty || forceRefresh) && response['meta'] != null) {
      final meta = response['meta'] as Map<String, dynamic>;
      if (meta.containsKey('building_names')) {
        final buildingNames = meta['building_names'] as List<dynamic>;
        _buildingNames = buildingNames.map((name) => name.toString()).toList();

        // Don't add "All Buildings" option - select first building by default
        if (_buildingNames.isNotEmpty) {
          if (_selectedBuildingName == null || forceRefresh) {
            _selectedBuildingName = _buildingNames[0];
          }
        }

        // Cache the building names
        await _cacheBuildingNames(_buildingNames);
      }
    }
  }

  Future<void> deleteImage() async {
    GateStorage storage = GateStorage();
    await storage.init();
    await storage.removeVisitorImage();
    log("Image successfully removed.");
  }

  // Search and Filter Methods

  void _debouncedSearchMembers(String query) {
    // Cancel previous timer if it exists
    _debounceTimer?.cancel();

    // Reset searching state
    if (mounted) {
      setState(() {
        _isSearching = false;
      });
    }

    // Always perform local search first for immediate results
    _performLocalSearch(query);

    // Skip API search for now to avoid performance issues
    // Only use local search which is much faster and more reliable
  }

  void _performLocalSearch(String query) {
    try {
      if (query.trim().isEmpty) {
        _filteredMembersNotifier.value = _allMembers;
        return;
      }

      if (query.length >= 1) {
        final searchQuery = query.toLowerCase().trim();

        // Use a more efficient search approach
        final results = <dynamic>[];

        for (final member in _allMembers) {
          if (_matchesMemberLocally(member, searchQuery)) {
            results.add(member);
          }

          // Limit results for performance (max 30 results)
          if (results.length >= 30) break;
        }

        // Simple sorting - exact unit matches first, then alphabetical
        results.sort((a, b) {
          final unitA = a['unit_flat_number']?.toString().toLowerCase() ?? '';
          final unitB = b['unit_flat_number']?.toString().toLowerCase() ?? '';

          // Exact unit matches first
          if (unitA.startsWith(searchQuery) && !unitB.startsWith(searchQuery))
            return -1;
          if (unitB.startsWith(searchQuery) && !unitA.startsWith(searchQuery))
            return 1;

          // Then alphabetical by unit
          return unitA.compareTo(unitB);
        });

        _filteredMembersNotifier.value = results;
      } else {
        _filteredMembersNotifier.value = _allMembers;
      }
    } catch (e) {
      // If search fails, show all members
      _filteredMembersNotifier.value = _allMembers;
    }
  }

  bool _matchesMemberLocally(dynamic member, String searchQuery) {
    try {
      // Apply building filter if a building is selected
      if (_selectedBuildingName != null && _selectedBuildingName!.isNotEmpty) {
        final socBuildingName = member['soc_building_name']?.toString() ?? '';
        if (socBuildingName != _selectedBuildingName) {
          return false;
        }
      }

      // Fast unit number check first (most common search)
      final unitFlatNumber =
          member['unit_flat_number']?.toString().toLowerCase() ?? '';
      if (unitFlatNumber.contains(searchQuery)) {
        return true;
      }

      // Then building check
      final buildingUnit =
          member['building_unit']?.toString().toLowerCase() ?? '';
      if (buildingUnit.contains(searchQuery)) {
        return true;
      }

      // Name check - simplified for performance
      final memberDetails = (member['rows'] as List<dynamic>?) ?? [];
      for (final detail in memberDetails) {
        final firstName =
            detail['member_first_name']?.toString().toLowerCase() ?? '';
        final lastName =
            detail['member_last_name']?.toString().toLowerCase() ?? '';

        if (firstName.contains(searchQuery) || lastName.contains(searchQuery)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  int _calculateLocalRelevanceScore(dynamic member, String searchQuery) {
    int score = 0;

    final unitFlatNumber =
        member['unit_flat_number']?.toString().toLowerCase() ?? '';
    final buildingUnit =
        member['building_unit']?.toString().toLowerCase() ?? '';
    final socBuildingName =
        member['soc_building_name']?.toString().toLowerCase() ?? '';

    // Unit number gets highest priority
    if (unitFlatNumber == searchQuery)
      score += 100;
    else if (unitFlatNumber.startsWith(searchQuery))
      score += 80;
    else if (unitFlatNumber.contains(searchQuery)) score += 40;

    // Building unit matches
    if (buildingUnit == searchQuery)
      score += 60;
    else if (buildingUnit.startsWith(searchQuery))
      score += 40;
    else if (buildingUnit.contains(searchQuery)) score += 20;

    // Building name matches
    if (socBuildingName == searchQuery)
      score += 50;
    else if (socBuildingName.startsWith(searchQuery))
      score += 30;
    else if (socBuildingName.contains(searchQuery)) score += 15;

    // Name matches (check both member_details and rows)
    final memberDetails = (member['member_details'] as List<dynamic>?) ??
        (member['rows'] as List<dynamic>?) ??
        [];
    for (final detail in memberDetails) {
      final firstName =
          detail['member_first_name']?.toString().toLowerCase() ?? '';
      final lastName =
          detail['member_last_name']?.toString().toLowerCase() ?? '';
      final fullName = '$firstName $lastName'.trim();

      if (fullName.startsWith(searchQuery))
        score += 70;
      else if (firstName.startsWith(searchQuery) ||
          lastName.startsWith(searchQuery))
        score += 50;
      else if (fullName.contains(searchQuery)) score += 30;
    }

    return score;
  }

  Future<void> _searchMembersFromApi(String query) async {
    if (!mounted) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final String? companyId = await gateStorage.getSocietyId();
      if (companyId == null) {
        throw Exception("Company ID not found");
      }

      // Get access token
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      // Check if we have access token
      if (accessToken == null) {
        throw Exception('No authentication token found. Please log in again.');
      }

      final apiUrl = ApiUrls.memberList;

      log("Searching members with query: $query");

      final response = await Dio().get(
        apiUrl,
        queryParameters: {
          'company_id': companyId,
          'search': query,
        },
        options: Options(
          headers: {
            'Accept': 'application/json, text/plain, */*',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        final membersList = responseData['data'] ?? [];

        log('API search results: ${membersList.length} members found');

        if (mounted) {
          setState(() {
            _isSearching = false;
            _filteredMembersNotifier.value = membersList;
          });
        }
      } else {
        log('Failed to search members: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
          myFluttertoast(
            msg: "Failed to search members",
            backgroundColor: Colors.red,
          );
        }
      }
    } catch (e) {
      log('Error searching members: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        myFluttertoast(
          msg: "Error searching members: ${e.toString()}",
          backgroundColor: Colors.red,
        );
      }
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Enhanced Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xffF44336).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.people,
                            color: Color(0xffF44336),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Selected Members',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.close, size: 28, color: Colors.red),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(
                  thickness: 1,
                  height: 1,
                  color: Colors.black.withOpacity(0.1)),
              // Enhanced Members List
              Expanded(
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable: _selectedMembersNotifier,
                  builder: (context, selectedMembers, _) {
                    return ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: selectedMembers.length,
                      itemBuilder: (context, index) {
                        final member = selectedMembers.elementAt(index);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  const Color(0xffF44336).withOpacity(0.1),
                              child: const Icon(
                                Icons.person,
                                color: Color(0xffF44336),
                                size: 28,
                              ),
                            ),
                            title: Text(
                              member,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.close,
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
              // Enhanced Bottom Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Builder(
                  builder: (context) {
                    final bool isTablet =
                        MediaQuery.of(context).size.width > 768;
                    return Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Color(0xffF44336), width: 1),
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
                                color: Color(0xffF44336),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF212427), Color(0xFF57636C)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black87.withOpacity(0.25),
                                  blurRadius: 32,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 32 : 24,
                                    vertical: isTablet ? 16 : 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32),
                                ),
                                elevation: 32,
                                shadowColor: Colors.transparent,
                              ),
                              onPressed: selectedMembers.isEmpty ||
                                      _isConfirming
                                  ? null
                                  : () =>
                                      _handleSelectionSubmit(selectedMembers),
                              child: const Text(
                                'Confirm',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
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
      'rows': formattedMemberDetails,
      'unit_ids': unitIDs.whereType<int>().toList(),
      'member_ids': selectedMemberIds.toList(),
      'building_unit': selectedBuildingUnits.toList(),
      'member_old_sso_id': selectedUserIds.first
    };
    log('Saved member and unit details: ${jsonEncode(savedMemberUnitDetails)}');
  }

  // Building Selection Methods
  Future<void> _handleBuildingSelection(String buildingName) async {
    setState(() {
      _isLoading = true;
      // Set the selected building name directly
      _selectedBuildingName = buildingName;
    });

    await _initializeMembers(forceRefresh: false);

    setState(() {
      _isLoading = false;
    });
  }

  // Refresh data from API
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    await _initializeMembers(forceRefresh: true);

    setState(() {
      _isLoading = false;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Members data refreshed successfully',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 3000),
        elevation: 8,
      ),
    );
  }

  // UI Methods
  Widget _buildBuildingsList() {
    if (_buildingNames.isEmpty) {
      return const SizedBox
          .shrink(); // Don't show anything if no building names
    }

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _buildingNames.length,
        itemBuilder: (context, index) {
          final buildingName = _buildingNames[index];
          final isSelected = buildingName == _selectedBuildingName;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              checkmarkColor: Colors.white,
              label: Text(buildingName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  _handleBuildingSelection(buildingName);
                }
              },
              backgroundColor: Colors.grey[200],
              selectedColor: Colors.black,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  // UI Methods
  Widget _buildSearchField(BuildContext context) {
    return CustomForm.textField(
      'Search Members',
      titleColor: Theme.of(context).colorScheme.onSurface,
      hintColor: Theme.of(context).colorScheme.onSurface.withAlpha(128),
      hintText: 'Search Members (type at least 3 characters)',
      textController: _searchController,
      onChanged: (query) {
        if (query.trim().length >= 3) {
          _debouncedSearchMembers(query.trim());
        } else {
          _filteredMembersNotifier.value = _allMembers;
        }
      },
      suffixIcon: _isSearching
          ? Container(
              width: 24,
              height: 24,
              padding: const EdgeInsets.all(6),
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey,
              ),
            )
          : _searchController.text.isNotEmpty
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

            if (_isSearching) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.black,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Searching members...',
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
            'No Members Found.\nType at least 3 characters to search members by their name or flat',
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
      padding: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        120,
      ),
      itemCount: filteredMembers.length,
      itemBuilder: (context, index) =>
          _buildMemberTile(filteredMembers[index], selectedMembers),
    );
  }

  Widget _buildMemberTile(dynamic member, Set<String> selectedMembers) {
    final memberDetails = member['rows'] as List<dynamic>? ?? [];
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
          memberDetails.length == 1
              ? '1 member'
              : '${memberDetails.length} members',
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
    final bool isTablet = MediaQuery.of(context).size.width > 768;

    log("widget.selfcheckinFlow ${widget.selfcheckinFlow}");
    return WillPopScope(
      onWillPop: () async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'visitor recording terminated',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(milliseconds: 2500),
            elevation: 8,
          ),
        );
        if (widget.searchedVisitor != null) {
          Navigator.pop(context);
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
        }
        return false; // Prevent default back navigation.
      },
      child: Scaffold(
        backgroundColor: const Color(0xffF5F5F5),
        appBar: _buildEnhancedAppBar(context, isTablet),
        body: SafeArea(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                // Enhanced Tab Bar Section
                _buildEnhancedTabBar(context, isTablet),

                // Enhanced Content Section
                Expanded(
                  child: TabBarView(
                    children: [
                      // First Tab - Select Units/Members
                      _buildUnitsSelectionTab(context, isTablet),

                      // Second Tab - Society Office
                      _buildSocietyOfficeTab(context, isTablet),
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

  PreferredSizeWidget _buildEnhancedAppBar(
      BuildContext context, bool isTablet) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      leading: Container(
        margin: EdgeInsets.all(isTablet ? 12 : 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: const Color(0xff57636C),
            size: isTablet ? 20 : 18,
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'visitor recording terminated',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
                duration: const Duration(milliseconds: 2500),
                elevation: 8,
              ),
            );
            if (widget.searchedVisitor != null) {
              Navigator.pop(context);
            } else {
              widget.selfcheckinFlow
                  ? Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SelfHomeView()),
                      (Route<dynamic> route) => false,
                    )
                  : Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const GateDashboardView()),
                      (Route<dynamic> route) => false,
                    );
            }
          },
        ),
      ),
      title: Text(
        "Select",
        style: TextStyle(
          color: const Color(0xff212427),
          fontSize: isTablet ? 24 : 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: false,
      actions: [
        Container(
          margin: EdgeInsets.only(right: isTablet ? 16 : 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _isLoading ? null : _refreshData,
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 10 : 8),
                child: _isLoading
                    ? SizedBox(
                        width: isTablet ? 22 : 18,
                        height: isTablet ? 22 : 18,
                        child: const CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        Icons.refresh,
                        color: Colors.black,
                        size: isTablet ? 22 : 18,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedTabBar(BuildContext context, bool isTablet) {
    return Container(
      margin: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xffF44336).withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        height: isTablet ? 60 : 56,
        padding: const EdgeInsets.all(4),
        child: TabBar(
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xffF44336),
                Color(0xffD32F2F),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xffF44336).withOpacity(0.3),
                spreadRadius: 0,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xff57636C),
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w500,
          ),
          tabs: [
            Tab(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
                child: const Text(
                  'Select Units/Members',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Tab(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
                child: const Text(
                  'Society Office',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitsSelectionTab(BuildContext context, bool isTablet) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                // Enhanced Search Section
                _buildEnhancedSearchSection(context, isTablet),

                // Enhanced Building Selection
                _buildEnhancedBuildingSelection(context, isTablet),

                // Enhanced Member List
                Expanded(
                  child: Container(
                    margin:
                        EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
                    child: _buildEnhancedMemberList(context, isTablet),
                  ),
                ),
              ],
            ),

            // Enhanced Selected Members Bottom Bar
            _buildEnhancedBottomSelectionBar(context, isTablet),
          ],
        );
      },
    );
  }

  Widget _buildSocietyOfficeTab(BuildContext context, bool isTablet) {
    return Container(
      margin: EdgeInsets.all(isTablet ? 20 : 16),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(isTablet ? 40 : 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xffF44336).withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isTablet ? 80 : 60,
                height: isTablet ? 80 : 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xffF44336),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xffF44336).withOpacity(0.08),
                      spreadRadius: 0,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.business,
                  color: const Color(0xffF44336),
                  size: isTablet ? 32 : 24,
                ),
              ),
              SizedBox(height: isTablet ? 24 : 20),
              Text(
                "Society Office",
                style: TextStyle(
                  fontSize: isTablet ? 24 : 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff212427),
                ),
              ),
              SizedBox(height: isTablet ? 12 : 8),
              Text(
                "Check-in directly with society office for administrative purposes",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isTablet ? 14 : 12,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              SizedBox(height: isTablet ? 32 : 24),

              // Enhanced Check-in Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black,
                      Colors.grey,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      spreadRadius: 0,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _isLoading ? null : _handleSocietyOfficeCheckIn,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 32 : 24,
                        vertical: isTablet ? 20 : 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isLoading) ...[
                            SizedBox(
                              width: isTablet ? 24 : 20,
                              height: isTablet ? 24 : 20,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: isTablet ? 16 : 12),
                            Text(
                              "Checking in...",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isTablet ? 18 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ] else ...[
                            Container(
                              width: isTablet ? 24 : 20,
                              height: isTablet ? 24 : 20,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                                size: isTablet ? 16 : 14,
                              ),
                            ),
                            SizedBox(width: isTablet ? 16 : 12),
                            Text(
                              "Tap to Check-in",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isTablet ? 18 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (_isLoading) ...[
                SizedBox(height: isTablet ? 20 : 16),
                Text(
                  "Please wait while we process your check-in",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSocietyOfficeCheckIn() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Create building assignment for society office
      final buildingAssignment = BuildingAssignment(
        id: null,
        visitor_id: widget.visitor.id,
        visitor_log_id: null,
        company_id: int.parse(companyId.toString()),
        building_id: 0,
        unit_id: ["0001"],
      );

      // Create visitor log data for society office
      final visitorLogData = VisitorLog(
        visitor_id: widget.visitor.id ?? 0,
        visitor_purpose_category_id: widget.purposeCategoryId == null
            ? 1
            : int.parse(widget.purposeCategoryId.toString()),
        visitor_purpose_sub_category_id: widget.selectedSubCategoryId != null
            ? int.parse(widget.selectedSubCategoryId.toString())
            : null,
        visitor_count: widget.guestCount ?? 0,
        visitor: widget.visitor,
        visitor_purpose_Category_name: widget.purposeCategory.categoryName,
        visitor_check_in: DateTime.parse(formattedInTime),
        visitor_card_number: widget.visitorNumber,
        visitor_coming_from: widget.comingFrom,
        visitor_building_assignment: [buildingAssignment],
        visitor_card_id: null,
        carNumber: widget.carNumber,
        company_id: int.parse(companyId.toString()),
        is_checked_out: false,
      );

      // Save society office details to preferences
      final prefs = await SharedPreferences.getInstance();
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
        'rows',
        json.encode(societyOfficeMemberDetails),
      );

      // Perform check-in
      await remoteDataSource.checkIn(visitorLogData, true);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Visitor checked in successfully',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(milliseconds: 3000),
          elevation: 8,
        ),
      );

      // Navigate to dashboard
      if (mounted) {
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
      }
    } catch (e) {
      log('Error during society office check-in: $e');
      if (mounted) {
        myFluttertoast(
          msg: "Error during check-in. Please try again.",
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
  }

  // Selection Submission Methods
  Future<void> _handleSelectionSubmit(Set<String> selectedMembers) async {
    if (_isConfirming) return;
    setState(() {
      _isConfirming = true;
    });
    await deleteImage();
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
      setState(() {
        _isConfirming = false;
      });
    }
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

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
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
                  userId: selectedUserIds.first,
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

  bool _isButtonDisabled = false;

  bool statusallowed = false;

  Widget _buildEnhancedSearchSection(BuildContext context, bool isTablet) {
    return Container(
      margin: EdgeInsets.all(isTablet ? 20 : 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 0,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _searchController,
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  color: const Color(0xff212427),
                ),
                decoration: InputDecoration(
                  hintText: 'Search by name, unit number, or building...',
                  hintStyle: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    color: const Color(0xff57636C),
                  ),
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xffF44336).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.search,
                      color: const Color(0xffF44336),
                      size: isTablet ? 20 : 18,
                    ),
                  ),
                  suffixIcon: _isSearching
                      ? Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.all(16),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xffF44336)),
                          ),
                        )
                      : _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Color(0xff57636C),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _filteredMembersNotifier.value = _allMembers;
                                // Cancel any pending search operations
                                _debounceTimer?.cancel();
                                setState(() {
                                  _isSearching = false;
                                });
                              },
                            )
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isTablet ? 20 : 16,
                  ),
                ),
                onChanged: (query) {
                  if (query.trim().length >= 1) {
                    _debouncedSearchMembers(query.trim());
                  } else {
                    _filteredMembersNotifier.value = _allMembers;
                  }
                },
                cursorColor: Colors.black,
              ),
            ),
          ),
          // Search results info with better feedback
          if (_searchController.text.length >= 1)
            Container(
              margin: EdgeInsets.only(left: isTablet ? 12 : 8),
              child: ValueListenableBuilder<List<dynamic>>(
                valueListenable: _filteredMembersNotifier,
                builder: (context, filteredMembers, _) {
                  final memberCount =
                      filteredMembers.fold<int>(0, (count, member) {
                    final memberDetails =
                        member['rows'] as List<dynamic>? ?? [];
                    return count + memberDetails.length;
                  });

                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 12 : 8,
                      vertical: isTablet ? 8 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffF44336).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xffF44336).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          filteredMembers.isEmpty
                              ? Icons.search_off
                              : Icons.people,
                          size: isTablet ? 16 : 14,
                          color: const Color(0xffF44336),
                        ),
                        SizedBox(width: isTablet ? 6 : 4),
                        Text(
                          filteredMembers.isEmpty
                              ? 'No results'
                              : memberCount == 1
                                  ? '1 member'
                                  : '$memberCount members',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xffF44336),
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
    );
  }

  Widget _buildEnhancedBuildingSelection(BuildContext context, bool isTablet) {
    if (_buildingNames.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: isTablet ? 12 : 8),
            child: Text(
              "Select Building",
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff212427),
              ),
            ),
          ),
          Container(
            height: isTablet ? 56 : 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _buildingNames.length,
              itemBuilder: (context, index) {
                final buildingName = _buildingNames[index];
                final isSelected = buildingName == _selectedBuildingName;

                return Container(
                  margin: EdgeInsets.only(right: isTablet ? 12 : 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? const Color(0xffFDEAEA) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xffF44336).withOpacity(0.25)
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade50.withOpacity(0.25),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _handleBuildingSelection(buildingName),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 20 : 16,
                            vertical: isTablet ? 16 : 12,
                          ),
                          child: Text(
                            buildingName,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xffF44336)
                                  : Colors.black,
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: isTablet ? 16 : 12),
        ],
      ),
    );
  }

  Widget _buildEnhancedMemberList(BuildContext context, bool isTablet) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _selectedMembersNotifier,
      builder: (context, selectedMembers, child) {
        return ValueListenableBuilder<List<dynamic>>(
          valueListenable: _filteredMembersNotifier,
          builder: (context, filteredMembers, child) {
            if (_isLoading) {
              return const LoaderView(
                title: "Loading Members",
                subtitle: "Please wait while we fetch member information",
              );
            }

            if (_isSearching) {
              return const LoaderView(
                title: "Searching Members",
                subtitle: "Finding members matching your search criteria",
              );
            }

            if (filteredMembers.isEmpty) {
              return _buildEnhancedEmptyState(context, isTablet);
            }

            return _buildEnhancedMemberListView(
                filteredMembers, selectedMembers, isTablet);
          },
        );
      },
    );
  }

  Widget _buildEnhancedEmptyState(BuildContext context, bool isTablet) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: isTablet ? 40 : 32,
        bottom: MediaQuery.of(context).viewInsets.bottom + (isTablet ? 40 : 32),
        left: isTablet ? 40 : 32,
        right: isTablet ? 40 : 32,
      ),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(isTablet ? 40 : 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isTablet ? 80 : 60,
                height: isTablet ? 80 : 60,
                decoration: BoxDecoration(
                  color: const Color(0xffF44336).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.groups_outlined,
                  color: const Color(0xffF44336),
                  size: isTablet ? 32 : 24,
                ),
              ),
              SizedBox(height: isTablet ? 24 : 20),
              Text(
                'No Members Found',
                style: TextStyle(
                  fontSize: isTablet ? 20 : 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff212427),
                ),
              ),
              SizedBox(height: isTablet ? 12 : 8),
              Text(
                'Type at least 3 characters to search members by their name or flat number',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isTablet ? 14 : 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedMemberListView(List<dynamic> filteredMembers,
      Set<String> selectedMembers, bool isTablet) {
    // Show no results state when search is active but no results found
    if (filteredMembers.isEmpty && _searchController.text.trim().length >= 1) {
      return _buildNoResultsState(isTablet);
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: isTablet ? 140 : 120,
        top: isTablet ? 8 : 4,
      ),
      itemCount: filteredMembers.length,
      itemBuilder: (context, index) => _buildEnhancedMemberTile(
          filteredMembers[index], selectedMembers, isTablet),
    );
  }

  Widget _buildNoResultsState(bool isTablet) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 40 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isTablet ? 80 : 64,
              height: isTablet ? 80 : 64,
              decoration: BoxDecoration(
                color: const Color(0xffF44336).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.search_off,
                size: isTablet ? 40 : 32,
                color: const Color(0xffF44336),
              ),
            ),
            SizedBox(height: isTablet ? 24 : 16),
            Text(
              'No members found',
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xff212427),
              ),
            ),
            SizedBox(height: isTablet ? 12 : 8),
            Text(
              'Try searching with different keywords:\n• Member name (first or last)\n• Unit number\n• Building name',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            SizedBox(height: isTablet ? 24 : 16),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                _filteredMembersNotifier.value = _allMembers;
                _debounceTimer?.cancel();
                setState(() {
                  _isSearching = false;
                });
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Search'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xffF44336),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 16,
                  vertical: isTablet ? 12 : 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchingState(bool isTablet) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 40 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: isTablet ? 48 : 32,
              height: isTablet ? 48 : 32,
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xffF44336)),
              ),
            ),
            SizedBox(height: isTablet ? 24 : 16),
            Text(
              'Searching members...',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedMemberTile(
      dynamic member, Set<String> selectedMembers, bool isTablet) {
    final memberDetails = member['rows'] as List<dynamic>? ?? [];
    final unitFlatNumber = member['unit_flat_number']?.toString() ?? 'N/A';
    final buildingUnit = member['building_unit']?.toString() ?? 'N/A';
    final socBuildingName = member['soc_building_name']?.toString() ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      child: Material(
        elevation: 0,
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // Remove any border from Material
        // No border property set
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent, // Remove all dividers
          ),
          child: ExpansionTile(
            tilePadding: EdgeInsets.all(isTablet ? 20 : 16),
            childrenPadding: EdgeInsets.zero,
            backgroundColor: Colors.transparent, // Remove background color
            collapsedBackgroundColor: Colors.transparent, // Remove collapsed bg
            // No border property set
            leading: Container(
              width: isTablet ? 48 : 40,
              height: isTablet ? 48 : 40,
              decoration: BoxDecoration(
                color: const Color(0xffF44336).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.location_city,
                color: const Color(0xffF44336),
                size: isTablet ? 24 : 20,
              ),
            ),
            title: Text(
              '$socBuildingName - $unitFlatNumber',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff212427),
              ),
            ),
            subtitle: Text(
              memberDetails.length == 1
                  ? '1 member'
                  : '${memberDetails.length} members',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: Colors.grey[600],
              ),
            ),
            iconColor: const Color(0xffF44336),
            collapsedIconColor: const Color(0xff57636C),
            children: memberDetails.isEmpty
                ? [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 20 : 16),
                      child: Text(
                        'No members available',
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  ]
                : _buildEnhancedMemberDetailsList(
                    memberDetails, member, isTablet),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEnhancedMemberDetailsList(
      List<dynamic> memberDetails, dynamic member, bool isTablet) {
    return [
      Divider(
        color: Colors.grey.withOpacity(0.2),
        thickness: 1,
        height: isTablet ? 8 : 6,
        indent: isTablet ? 20 : 16,
        endIndent: isTablet ? 20 : 16,
      ),
      ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: memberDetails.length,
        itemBuilder: (context, index) => _buildEnhancedMemberDetailsItem(
            memberDetails[index], member, isTablet),
      ),
    ];
  }

  Widget _buildEnhancedMemberDetailsItem(
      dynamic detail, dynamic member, bool isTablet) {
    final firstName = detail['member_first_name']?.toString() ?? 'N/A';
    final lastName = detail['member_last_name']?.toString() ?? '';
    final memberName = "$firstName $lastName";
    final userId = detail['user_id']?.toString() ?? '';
    final unitId = member['fk_unit_id'] ?? 0;
    final memberId = detail['member_id'] ?? 0;
    final buildingUnit = member['building_unit']?.toString() ?? 'N/A';
    final memberMobileNo =
        detail['member_mobile_number']?.toString().trim() ?? '';
    final isSelected = _selectedMembersNotifier.value.contains(memberName);

    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16, vertical: isTablet ? 8 : 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
          child: Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xffF44336).withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: const Color(0xffF44336).withOpacity(0.3))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: isTablet ? 40 : 32,
                  height: isTablet ? 40 : 32,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xffF44336)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    color: isSelected ? Colors.white : Colors.grey[600],
                    size: isTablet ? 20 : 16,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memberName,
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff212427),
                        ),
                      ),
                      if (memberMobileNo.isNotEmpty) ...[
                        SizedBox(height: isTablet ? 4 : 2),
                        Text(
                          "Mobile: " +
                              (memberMobileNo.length > 4
                                  ? memberMobileNo.substring(
                                          0, memberMobileNo.length - 4) +
                                      'X' * 4
                                  : 'X' * memberMobileNo.length),
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: isTablet ? 32 : 24,
                  height: isTablet ? 32 : 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.green
                        : Colors.grey.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected ? Icons.check : Icons.add,
                    color: isSelected ? Colors.white : Colors.grey[600],
                    size: isTablet ? 16 : 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedBottomSelectionBar(BuildContext context, bool isTablet) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ValueListenableBuilder<Set<String>>(
        valueListenable: _selectedMembersNotifier,
        builder: (context, selectedMembers, _) {
          if (selectedMembers.isEmpty) {
            return const SizedBox.shrink();
          }

          return Builder(
            builder: (context) {
              if (DefaultTabController.of(context).index != 0) {
                return const SizedBox.shrink();
              }

              return Container(
                margin: EdgeInsets.all(isTablet ? 20 : 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xffF44336),
                      Color(0xffD32F2F),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xffF44336).withOpacity(0.3),
                      spreadRadius: 0,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () =>
                        _showSelectedMembersBottomSheet(selectedMembers),
                    child: Padding(
                      padding: EdgeInsets.all(isTablet ? 20 : 16),
                      child: Row(
                        children: [
                          Container(
                            width: isTablet ? 48 : 40,
                            height: isTablet ? 48 : 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.people,
                              color: Colors.white,
                              size: isTablet ? 24 : 20,
                            ),
                          ),
                          SizedBox(width: isTablet ? 16 : 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  selectedMembers.length > 1
                                      ? '${selectedMembers.length} Members Selected'
                                      : selectedMembers.first,
                                  style: TextStyle(
                                    fontSize: isTablet ? 16 : 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: isTablet ? 4 : 2),
                                Text(
                                  "Tap to view details",
                                  style: TextStyle(
                                    fontSize: isTablet ? 12 : 10,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF212427),
                                    Color(0xFF57636C)
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black87.withOpacity(0.25),
                                    blurRadius: 32,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: isTablet ? 32 : 24,
                                      vertical: isTablet ? 16 : 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  elevation: 32,
                                  shadowColor: Colors.transparent,
                                ),
                                onPressed: selectedMembers.isEmpty ||
                                        _isConfirming
                                    ? null
                                    : () =>
                                        _handleSelectionSubmit(selectedMembers),
                                child: const Text(
                                  'Confirm',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
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
      await prefs.setString('rows', memberDetailsJson);
      print('Successfully saved member details: $memberDetailsJson');
    } catch (e) {
      print('Error saving member details: $e');
    }

    return VisitorLog(
      visitor_id: int.parse(widget.visitor.id.toString()),
      visitor_purpose_category_id: widget.purposeCategoryId == null
          ? 1
          : int.parse(widget.purposeCategoryId.toString()),
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
      visitor: widget.visitor,
    );
  }

  Future<List<Map<String, dynamic>>> getSavedMemberDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final String? memberDetailsJson = prefs.getString('rows');

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
      "self_check_in": widget.selfcheckinFlow.toString(),
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
