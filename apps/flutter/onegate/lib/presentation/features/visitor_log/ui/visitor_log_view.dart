// ignore_for_file: prefer_const_constructors

import 'dart:developer';
import 'dart:async';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_provider.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/bloc/visitor_log_bloc.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/ui/visitor_Details.dart';
import 'package:flutter_onegate/presentation/widgets/assign_card_popup.dart';
import 'package:flutter_onegate/utils/app_utils.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class VisitorLogView extends StatefulWidget {
  String id;
  final List<String> logList;
  final String? selectedBuilding;
  int? societyID;

  VisitorLogView({
    required this.id,
    required this.logList,
    this.selectedBuilding,
    Key? key,
  }) : super(key: key);

  @override
  State<VisitorLogView> createState() => _VisitorLogViewState();
}

class _VisitorLogViewState extends State<VisitorLogView>
    with TickerProviderStateMixin {
  late VisitorLogBloc _visitorLogBloc;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  String? _searchText = '';
  String? selectedBuilding;
  String? selectedGateName;
  int? societyId;
  final GateStorage gateStorage = GateStorage();
  String _currentSection = 'ALL'; // Track current section

  // Add missing variables to fix compilation errors
  String? selectedId;
  final RemoteDataSource remoteDataSource = RemoteDataSource();

  // Add timer for debounced search
  Timer? _searchTimer;

  // Keep track of last successful data to show during search loading
  List<VisitorLog>? _lastVisitorLogs;
  final bool _isSearching = false;

  // Track loading more state for pagination
  bool _isLoadingMore = false;

  int current_page = 1;
  final int per_page = 10;

  // Visitor card entry setting
  bool _visitorCardEntryEnabled = false;

  @override
  void initState() {
    super.initState();
    _visitorLogBloc = BlocProvider.of<VisitorLogBloc>(context);
    getSelectedGate();
    _initializeSocietyId();
    _loadVisitorCardSetting();
    _initializeLogs();

    // Initialize selectedBuilding after context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          selectedBuilding = context.l10n.allBuildings ?? "All Buildings";
        });
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        // Load more data when reaching the bottom
        final currentState = _visitorLogBloc.state;
        if (currentState is VisitorLogSuccessState &&
            currentState.hasMoreData!) {
          final nextPage = currentState.currentPage! + 1;

          // Determine filter type based on current section
          String filterType = "all";
          if (_currentSection == 'CHECK_IN') {
            filterType = "check_in";
          } else if (_currentSection == 'CHECK_OUT') {
            filterType = "check_out";
          }

          debugPrint(
              "Loading more data for page $nextPage with filter: $filterType");
          debugPrint("Filter type: $filterType, Section: $_currentSection");

          // Handle pagination differently for card number search vs backend search
          if (_isCardNumberPattern(_searchText ?? '')) {
            // For card number search, load more data without search filter
            _visitorLogBloc.add(LoadMoreVisitorLogsEvent(
              nextPage,
              100, // Get more data for client-side filtering
              filterType: filterType,
              searchQuery: null, // No backend search for card numbers
            ));
          } else {
            // For backend search, use existing logic
            _visitorLogBloc.add(LoadMoreVisitorLogsEvent(
              nextPage,
              per_page,
              filterType: filterType,
              searchQuery: _searchText,
            ));
          }
        } else {
          debugPrint(context.l10n.noMoreData ?? 'No more data');
        }
      } else {
        final currentState = _visitorLogBloc.state;
        debugPrint(
            "State is not VisitorLogSuccessState: ${currentState.runtimeType}");
      }
    });
  }

  void _refreshVisitorLogList() {
    // Refresh visitor log list after card assignment
    switch (_resolvedVisitorLogType(widget.id)) {
      case "In Out Book":
        _visitorLogBloc.add(FetchVisitorLogEvent(
          DateTime.now(),
          currentPage: 1,
          perPage: per_page,
        ));
        break;
      case "Visitor In":
        _visitorLogBloc.add(FetchCheckInLogEvent(
          DateTime.now(),
          currentPage: 1,
          perPage: per_page,
        ));
        break;
      case "Cards":
      case "Visitor Out":
        _visitorLogBloc.add(FetchCheckOutLogEvent(
          DateTime.now(),
          currentPage: 1,
          perPage: per_page,
        ));
        break;
    }
  }

  void _initializeLogs() {
    debugPrint("VisitorLogView initialized with ID: '${widget.id}'");

    switch (_resolvedVisitorLogType(widget.id)) {
      case "In Out Book":
        debugPrint("Triggering FetchVisitorLogEvent for In Out Book");
        _currentSection = "ALL";
        _visitorLogBloc.add(FetchVisitorLogEvent(
          DateTime.now(),
          currentPage: 1,
          perPage: 10,
        ));
        break;
      case "Visitor In":
        debugPrint("Triggering FetchCheckInLogEvent for Visitor In");
        _currentSection = "CHECK_IN";
        _visitorLogBloc.add(FetchCheckInLogEvent(
          DateTime.now(),
          currentPage: 1,
          perPage: 10,
        ));
        break;
      case "Cards":
        debugPrint("Triggering FetchCheckOutLogEvent for Cards");
        _currentSection = "CHECK_OUT";
        _visitorLogBloc.add(FetchCheckOutLogEvent(
          DateTime.now(),
          currentPage: 1,
          perPage: 10,
        ));
        break;
      case "Visitor Out":
        debugPrint("Triggering FetchCheckOutLogEvent for Visitor Out");
        _currentSection = "CHECK_OUT";
        _visitorLogBloc.add(FetchCheckOutLogEvent(
          DateTime.now(),
          currentPage: 1,
          perPage: 10,
        ));
        break;
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchTimer?.cancel(); // Cancel search timer
    super.dispose();
  }

  // Add method to trigger search with debouncing
  void _triggerSearch(String query) {
    // Cancel any existing timer
    _searchTimer?.cancel();

    // Set a new timer for debounced search
    _searchTimer = Timer(Duration(milliseconds: 500), () {
      debugPrint(
          "${context.l10n.triggeringSearchFor ?? 'Triggering search for'}: '$query'"); // Localized

      final isCardNumber = _isCardNumberPattern(query.trim());

      if (isCardNumber) {
        // For card numbers: fetch all data and filter client-side
        _performCardNumberSearch(query.trim());
      } else {
        // For names/mobile: use existing backend search
        _performBackendSearch(query);
      }
    });
  }

  // Check if the query looks like a card number
  bool _isCardNumberPattern(String query) {
    if (query.isEmpty) return false;
    // Match patterns like: V123, VC-045, 123, V-123, etc.
    return RegExp(r'^[A-Za-z\-]*\d+[A-Za-z\-]*$').hasMatch(query);
  }

  // Perform card number search by fetching all data and filtering client-side
  void _performCardNumberSearch(String cardNumber) {
    debugPrint(
        "🔍 [CARD SEARCH] Performing card number search for: '$cardNumber'");

    // Fetch all data without search filter for client-side filtering
    switch (_resolvedVisitorLogType(widget.id)) {
      case "Visitor In":
        _visitorLogBloc.add(FetchCheckInLogEvent(
          DateTime.now(),
          currentPage: 1,
          perPage: 100, // Get more data for client-side filtering
          searchQuery: null, // No backend search
        ));
        break;
      case "Visitor Out":
      case "Cards":
        _visitorLogBloc.add(FetchCheckOutLogEvent(
          DateTime.now(),
          currentPage: 1,
          perPage: 100,
          searchQuery: null,
        ));
        break;
      default:
        _visitorLogBloc.add(FetchVisitorLogEvent(
          DateTime.now(),
          currentPage: 1,
          perPage: 100,
          searchQuery: null,
        ));
    }
  }

  // Perform backend search for names/mobile numbers
  void _performBackendSearch(String query) {
    debugPrint("🔍 [BACKEND SEARCH] Performing backend search for: '$query'");

    // Trigger the appropriate BLoC event based on current section
    if (_currentSection == 'CHECK_IN') {
      _visitorLogBloc.add(FetchCheckInLogEvent(
        DateTime.now(),
        currentPage: 1,
        perPage: per_page,
        searchQuery: query.isNotEmpty ? query : null,
      ));
    } else if (_currentSection == 'CHECK_OUT') {
      _visitorLogBloc.add(FetchCheckOutLogEvent(
        DateTime.now(),
        currentPage: 1,
        perPage: per_page,
        searchQuery: query.isNotEmpty ? query : null,
      ));
    } else {
      _visitorLogBloc.add(FetchVisitorLogEvent(
        DateTime.now(),
        currentPage: 1,
        perPage: per_page,
        searchQuery: query.isNotEmpty ? query : null,
      ));
    }
  }

  // Add method for handling search text changes
  void _onSearchChanged(String value) {
    setState(() {
      _searchText = value;
    });
    _triggerSearch(value);
  }

  // Add method for loading initial data
  void _loadInitialData() {
    debugPrint("Loading initial data for: ${widget.id}");

    switch (_resolvedVisitorLogType(widget.id)) {
      case "In Out Book":
        _visitorLogBloc.add(FetchVisitorLogEvent(
          DateTime.now(),
          currentPage: 1,
          perPage: 10,
        ));
        break;
      case "Visitor In":
        _visitorLogBloc.add(FetchCheckInLogEvent(
          DateTime.now(),
          currentPage: 1,
          perPage: 10,
        ));
        break;
      case "Cards":
      case "Visitor Out":
        _visitorLogBloc.add(FetchCheckOutLogEvent(
          DateTime.now(),
          currentPage: 1,
          perPage: 10,
        ));
        break;
    }
  }

  Future<void> getSelectedGate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedGateName = prefs.getString('selected_gate');
    });
  }

  Future<void> _initializeSocietyId() async {
    final societyIdStr = await gateStorage.getSocietyId();
    societyId = int.tryParse(societyIdStr ?? '0');
    log('Society ID: $societyId');
  }

  Future<void> _loadVisitorCardSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _visitorCardEntryEnabled = prefs.getBool('visitorCardNumber') ?? false;
    });
  }

  String _resolvedVisitorLogType(String id) {
    final raw = id.trim().toLowerCase();
    // Avoid inherited-widget access in initState by using widget inputs only.
    // logList is passed from dashboard in the active locale.
    final localizedInOut =
        widget.logList.isNotEmpty ? widget.logList[0].trim().toLowerCase() : '';
    final localizedVisitorIn =
        widget.logList.length > 1 ? widget.logList[1].trim().toLowerCase() : '';
    final localizedVisitorOut =
        widget.logList.length > 2 ? widget.logList[2].trim().toLowerCase() : '';

    if (raw == 'in out book' || raw == localizedInOut) return 'In Out Book';
    if (raw == 'visitor in' || raw == localizedVisitorIn) return 'Visitor In';
    if (raw == 'visitor out' || raw == localizedVisitorOut)
      return 'Visitor Out';
    if (raw == 'cards') return 'Cards';
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final yesterday = today.subtract(Duration(days: 1));

    return BlocConsumer<VisitorLogBloc, VisitorLogState>(
      bloc: _visitorLogBloc,
      listenWhen: (previous, current) =>
          current is VisitorLogActionState ||
          current is VisitorLogLoadingMoreState,
      buildWhen: (previous, current) {
        // Don't rebuild on loading state if we're searching and have previous data
        if (current is VisitorLogLoadingState &&
            _searchText!.isNotEmpty &&
            _lastVisitorLogs != null) {
          return false;
        }
        return current is! VisitorLogActionState &&
            current is! VisitorLogLoadingMoreState;
      },
      listener: (context, state) {
        switch (state.runtimeType) {
          case VisitorLogLoadingMoreState:
            setState(() {
              _isLoadingMore = true;
            });
            debugPrint("🔄 [PAGINATION] Started loading more data");
            break;
          case VisitorLogSuccessState:
            setState(() {
              _isLoadingMore = false;
            });
            debugPrint("✅ [PAGINATION] Finished loading more data");
            break;
          case VisitorLogCheckOutSuccessState:
            final successState = state as VisitorLogCheckOutSuccessState;
            if (successState.isCheckOut!) {
              _showEnhancedSuccessToast(
                title:
                    context.l10n.checkOutSuccessful ?? "Check-Out Successful",
                message: context.l10n.visitorCheckedOut ??
                    "Visitor has been checked out successfully",
                icon: Icons.logout_rounded,
              );
              _visitorLogBloc.add(FetchVisitorLogEvent(DateTime.now()));
            }
            break;
          case VisitorCheckInLogSuccessState:
            _visitorLogBloc.add(FetchCheckInLogEvent(Utils.getCurrentTime()));
            _showEnhancedSuccessToast(
              title: context.l10n.checkOutSuccessful,
              message: context.l10n.visitorCheckedOut,
              icon: Icons.logout_rounded,
            );
            break;
        }
      },
      builder: (context, state) {
        switch (state.runtimeType) {
          case VisitorLogLoadingState:
            // When coming from dashboard navigation, avoid showing the extra loader
            // since dashboard already shows appropriate loading states
            final resolvedType = _resolvedVisitorLogType(widget.id);
            if (resolvedType == 'In Out Book' ||
                resolvedType == 'Visitor In' ||
                resolvedType == 'Visitor Out') {
              return const SizedBox.shrink();
            }
            return DashboardLoader(
              title: context.tr('Loading Visitor Logs'),
              subtitle: context.tr('visitorLogFetchDataSubtitle'),
            );

          case VisitorLogSuccessState:
            final successState = state as VisitorLogSuccessState;
            debugPrint("🎯 [UI BUILD] VisitorLogSuccessState received:");
            debugPrint(
                "🎯 [UI BUILD] - visitorLogs count: ${successState.visitorLogs?.length}");
            debugPrint(
                "🎯 [UI BUILD] - currentPage: ${successState.currentPage}");
            debugPrint(
                "🎯 [UI BUILD] - hasMoreData: ${successState.hasMoreData}");
            debugPrint("🎯 [UI BUILD] - widget.id: ${widget.id}");

            final visitorLogs = (successState.visitorLogs ?? []).where((log) {
              if (_resolvedVisitorLogType(widget.id) == "Cards") {
                return log.visitor_card_number != null &&
                    log.visitor_card_number!.isNotEmpty;
              }
              return true; // Show all logs for other cases
            }).toList();

            // Apply client-side card number filtering if needed
            List<VisitorLog> displayLogs = visitorLogs;
            if (_isCardNumberPattern(_searchText ?? '') &&
                (_searchText?.isNotEmpty ?? false)) {
              debugPrint(
                  "🔍 [CLIENT FILTER] Applying card number filter for: '$_searchText'");
              displayLogs = visitorLogs.where((log) {
                final cardNumber = log.visitor_card_number?.toLowerCase() ?? '';
                final searchTerm = (_searchText ?? '').toLowerCase();
                return cardNumber.contains(searchTerm);
              }).toList();
              debugPrint(
                  "🔍 [CLIENT FILTER] Filtered ${visitorLogs.length} logs to ${displayLogs.length} matches");
            }

            // Store the visitor logs for future use during search loading
            _lastVisitorLogs = displayLogs;
            List<VisitorLog> uniqueVisitorLogs = [];
            Set<String> checkInTimes = {};

            for (var log in displayLogs) {
              final checkInTime = log.visitor_check_in?.toIso8601String();
              if (!checkInTimes.contains(checkInTime)) {
                checkInTimes.add(checkInTime!);
                uniqueVisitorLogs.add(log);
              }
            }

            // // Extract building names from visitor logs using the helper method
            // Set<String> buildingNames = BuildingDropdown.extractBuildingNames(
            //   uniqueVisitorLogs,
            //   getUnitName: (VisitorLog log) {
            //     if (log.visitor_building_assignment != null &&
            //         log.visitor_building_assignment!.isNotEmpty &&
            //         log.visitor_building_assignment!.first.unit_id != null &&
            //         log.visitor_building_assignment!.first.unit_id!
            //             .isNotEmpty) {
            //       return log.visitor_building_assignment!.first.unit_id!.first;
            //     }
            //     return "";
            //   },
            // );

            // List<String> sortedBuildingNames = buildingNames.toList();

            // Filter visitors by search (name or card number)
            List<VisitorLog> filteredVisitors = uniqueVisitorLogs;
            if ((_searchText?.isNotEmpty ?? false)) {
              if (_isCardNumberPattern(_searchText!)) {
                // For card number search, use the already filtered displayLogs
                filteredVisitors = displayLogs;
              } else {
                // For name/mobile search, apply name filtering
                filteredVisitors = uniqueVisitorLogs
                    .where((visitorLog) =>
                        visitorLog.visitor?.name
                            ?.toLowerCase()
                            .contains(_searchText!.toLowerCase()) ??
                        false)
                    .toList();
              }
            }

            // Filter by selected building if not "All Buildings"
            if (selectedBuilding != null &&
                selectedBuilding != context.l10n.allBuildings) {
              filteredVisitors = filteredVisitors.where((log) {
                if (log.visitor_building_assignment != null &&
                    log.visitor_building_assignment!.isNotEmpty &&
                    log.visitor_building_assignment!.first.unit_id != null &&
                    log.visitor_building_assignment!.first.unit_id!
                        .isNotEmpty) {
                  String unitId =
                      log.visitor_building_assignment!.first.unit_id!.first;
                  if (unitId.contains("-")) {
                    String buildingName = unitId.split("-")[0].trim();
                    return buildingName == selectedBuilding;
                  } else {
                    return unitId == selectedBuilding;
                  }
                }
                return false;
              }).toList();
            }

            final today = DateTime.now();
            final startOfToday = DateTime(today.year, today.month, today.day);
            final endOfToday = startOfToday.add(const Duration(days: 1));
            final startOfYesterday =
                startOfToday.subtract(const Duration(days: 1));
            final endOfYesterday = startOfToday;

            List<VisitorLog> todayLogs = filteredVisitors.where((log) {
              final checkInDate = log.visitor_check_in!;
              return checkInDate.isAfter(startOfToday) &&
                  checkInDate.isBefore(endOfToday);
            }).toList();

            List<VisitorLog> todayCheckoutLogs = filteredVisitors.where((log) {
              final checkOutDate = log.visitor_check_out;
              return checkOutDate != null &&
                  checkOutDate.isAfter(startOfToday) &&
                  checkOutDate.isBefore(endOfToday);
            }).toList();

            Future<void> storeTodayLogsCount(int count, String key) async {
              final prefs = await SharedPreferences.getInstance();
              prefs.setInt(key, count);
            }

            storeTodayLogsCount(todayLogs.length, 'todayLogsCount');
            storeTodayLogsCount(
                todayCheckoutLogs.length, 'todayCheckoutLogsCount');

            List<VisitorLog> yesterdayLogs = filteredVisitors.where((log) {
              final checkInDate = log.visitor_check_in!;
              return checkInDate.isAfter(startOfYesterday) &&
                  checkInDate.isBefore(endOfYesterday);
            }).toList();

            List<VisitorLog> olderLogs = filteredVisitors.where((log) {
              final checkInDate = log.visitor_check_in!;
              return checkInDate.isBefore(startOfYesterday);
            }).toList();
            bool isPopping = false;

            Map<String, List<VisitorLog>> groupedLogs = {};
            for (var log in filteredVisitors) {
              String dateKey =
                  DateFormat('yyyy-MM-dd').format(log.visitor_check_in!);
              if (!groupedLogs.containsKey(dateKey)) {
                groupedLogs[dateKey] = [];
              }
              groupedLogs[dateKey]!.add(log);
            }

// Convert the map to a list of entries
            List<MapEntry<String, List<VisitorLog>>> groupedLogsList =
                groupedLogs.entries.toList();

// Sort the list by date (most recent first)
            groupedLogsList.sort((a, b) => b.key.compareTo(a.key));

            return WillPopScope(
              onWillPop: () async {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => GateDashboardView()),
                  (Route<dynamic> route) => false,
                );
                return false;
              },
              child: MyScrollView(
                isScrollable: false,
                hasBackButton: true,
                backButtonPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => GateDashboardView()),
                    (Route<dynamic> route) => false,
                  );
                },
                pageTitleWidget: Hero(
                  tag: 'page_title',
                  child: Text(
                    _getLocalizedVisitorLogTitle(context, widget.id),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                actions: [
                  if (_resolvedVisitorLogType(widget.id) == "In Out Book" ||
                      _resolvedVisitorLogType(widget.id) == "Visitor In" ||
                      _resolvedVisitorLogType(widget.id) == "Visitor Out")
                    Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xff2C2C2C), // Black
                              Color(0xff6E6E6E), // Grey
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              await _showExportBottomSheet(
                                  context, visitorLogs);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10.0,
                                vertical: 6.0,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.download_rounded,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    context.l10n.export,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                ],
                pageBody: SizedBox(
                  height: MediaQuery.of(context).size.height,
                  child: Column(
                    children: [
                      Column(
                        children: [
                          // Building selection dropdown
                          // Search field
                          CustomForm.textField(
                            '',
                            focusNode: _searchFocusNode,
                            titleColor: Theme.of(context).colorScheme.onSurface,
                            hintColor: Theme.of(context).colorScheme.onSurface,
                            hintText: context.l10n.searchVisitor,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.search,
                            onFieldSubmitted: (value) {
                              log("🔍 [SEARCH] Searching for: '$value'");
                              // Trigger immediate search on submit
                              switch (_resolvedVisitorLogType(widget.id)) {
                                case "Visitor In":
                                  _visitorLogBloc.add(FetchCheckInLogEvent(
                                    DateTime.now(),
                                    currentPage: 1,
                                    perPage: 10,
                                    searchQuery:
                                        value.isNotEmpty ? value : null,
                                  ));
                                  break;
                                case "Visitor Out":
                                case "Cards":
                                  _visitorLogBloc.add(FetchCheckOutLogEvent(
                                    DateTime.now(),
                                    currentPage: 1,
                                    perPage: 10,
                                    searchQuery:
                                        value.isNotEmpty ? value : null,
                                  ));
                                  break;
                                default:
                                  _visitorLogBloc.add(FetchVisitorLogEvent(
                                    DateTime.now(),
                                    currentPage: 1,
                                    perPage: 10,
                                    searchQuery:
                                        value.isNotEmpty ? value : null,
                                  ));
                              }
                            },
                            onChanged: (value) {
                              setState(() {
                                _searchText = value;
                              });

                              // Cancel any existing timer
                              _searchTimer?.cancel();

                              // Start new timer for debounced search (500ms delay)
                              _searchTimer =
                                  Timer(const Duration(milliseconds: 500), () {
                                log("🔍 [SEARCH] Text changed, searching for: '$value'");

                                final searchQuery =
                                    value.isNotEmpty ? value : null;

                                switch (_resolvedVisitorLogType(widget.id)) {
                                  case "Visitor In":
                                    _visitorLogBloc.add(FetchCheckInLogEvent(
                                      DateTime.now(),
                                      currentPage: 1,
                                      perPage: 10,
                                      searchQuery: searchQuery,
                                    ));
                                    break;
                                  case "Visitor Out":
                                  case "Cards":
                                    _visitorLogBloc.add(FetchCheckOutLogEvent(
                                      DateTime.now(),
                                      currentPage: 1,
                                      perPage: 10,
                                      searchQuery: searchQuery,
                                    ));
                                    break;
                                  default:
                                    _visitorLogBloc.add(FetchVisitorLogEvent(
                                      DateTime.now(),
                                      currentPage: 1,
                                      perPage: 10,
                                      searchQuery: searchQuery,
                                    ));
                                    break;
                                }
                              });
                            },
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xffF44336).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    // Trigger search when search icon is pressed
                                    log("🔍 [SEARCH] Search button pressed with: '$_searchText'");

                                    // Create new instance to avoid BLoC issues
                                    final visitorLogBloc = VisitorLogBloc(
                                      VisitorLogUsecase(
                                        VisitorLogRepositoryImpl(
                                          RemoteDataSource(),
                                        ),
                                      ),
                                    );

                                    switch (
                                        _resolvedVisitorLogType(widget.id)) {
                                      case "Visitor In":
                                        visitorLogBloc.add(FetchCheckInLogEvent(
                                          DateTime.now(),
                                          currentPage: 1,
                                          perPage: 10,
                                          searchQuery:
                                              _searchText?.isNotEmpty == true
                                                  ? _searchText
                                                  : null,
                                        ));
                                        break;
                                      case "Visitor Out":
                                      case "Cards":
                                        visitorLogBloc
                                            .add(FetchCheckOutLogEvent(
                                          DateTime.now(),
                                          currentPage: 1,
                                          perPage: 10,
                                          searchQuery:
                                              _searchText?.isNotEmpty == true
                                                  ? _searchText
                                                  : null,
                                        ));
                                        break;
                                      default:
                                        visitorLogBloc.add(FetchVisitorLogEvent(
                                          DateTime.now(),
                                          currentPage: 1,
                                          perPage: 10,
                                          searchQuery:
                                              _searchText?.isNotEmpty == true
                                                  ? _searchText
                                                  : null,
                                        ));
                                    }
                                  },
                                  icon: const Icon(
                                    Ionicons.search_outline,
                                    color: Color(0xffF44336),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xffF44336).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    _showLogBookConfigBottomSheet(context);
                                  },
                                  icon: const Icon(
                                    Ionicons.funnel_outline,
                                    color: Color(0xffF44336),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // BuildingDropdown(
                          //   selectedBuilding: selectedBuilding,
                          //   onBuildingSelected: (String? value) {
                          //     setState(() {
                          //       selectedBuilding = value;
                          //     });
                          //   },
                          //   buildingNames: sortedBuildingNames,
                          // ),
                        ],
                      ),
                      Expanded(
                        child: _searchText!.isNotEmpty &&
                                filteredVisitors.isEmpty
                            ? _buildEnhancedEmptySearchState()
                            : filteredVisitors.isEmpty && _searchText!.isEmpty
                                ? _buildEnhancedEmptyVisitorsState()
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: EdgeInsets.only(bottom: 100),
                                    physics: BouncingScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: groupedLogsList.length +
                                        ((_isLoadingMore &&
                                                    successState.hasMoreData ==
                                                        true) ||
                                                (successState.hasMoreData ==
                                                        false &&
                                                    groupedLogsList.isNotEmpty)
                                            ? 1
                                            : 0),
                                    itemBuilder: (context, index) {
                                      // Show "no more visitor to load" message when pagination is complete
                                      if (index == groupedLogsList.length &&
                                          successState.hasMoreData == false &&
                                          groupedLogsList.isNotEmpty) {
                                        return _buildNoMoreVisitorsMessage();
                                      }

                                      // Show loading indicator at the bottom when loading more (only if there are more visitors to load)
                                      if (index == groupedLogsList.length &&
                                          _isLoadingMore &&
                                          successState.hasMoreData == true) {
                                        return _buildPaginationLoadingIndicator();
                                      }
                                      final dateKey =
                                          groupedLogsList[index].key;
                                      final logsForDate =
                                          groupedLogsList[index].value;

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16.0,
                                                vertical: 8.0),
                                            child: Chip(
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(
                                                    25), // Adjust the radius as needed
                                                side: BorderSide
                                                    .none, // No border
                                              ),
                                              side: BorderSide.none,
                                              label: Text(
                                                DateFormat('MMM dd, yyyy')
                                                    .format(DateTime.parse(
                                                        dateKey)),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall,
                                              ),
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                          Builder(builder: (context) {
                                            // No sorting - display logs as they come from the API response

                                            return ListView.builder(
                                              padding: EdgeInsets.zero,
                                              physics:
                                                  NeverScrollableScrollPhysics(),
                                              shrinkWrap: true,
                                              itemCount: logsForDate.length,
                                              itemBuilder: (context, logIndex) {
                                                return VisitorLogItem(
                                                  visitorLog:
                                                      logsForDate[logIndex],
                                                  isVisitorCardsView:
                                                      _resolvedVisitorLogType(
                                                              widget.id) ==
                                                          "Cards",
                                                  visitorCardEntryEnabled:
                                                      _visitorCardEntryEnabled,
                                                  onCardAssigned:
                                                      _refreshVisitorLogList,
                                                  onCheckOut: () {
                                                    setState(() {
                                                      logsForDate[logIndex]
                                                              .visitor_check_out =
                                                          Utils
                                                              .getCurrentTime();
                                                      logsForDate[logIndex]
                                                              .is_checked_out =
                                                          true;
                                                    });
                                                    // Use add instead of emit
                                                    _visitorLogBloc
                                                        .add(CheckOutEvent(
                                                      logsForDate[logIndex],
                                                      widget.id,
                                                    ));
                                                  },
                                                );
                                              },
                                            );
                                          }),
                                        ],
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          default:
            return Container();
        }
      },
    );
  }

  bool isLoading = false;

  // Build pagination loading indicator widget
  Widget _buildPaginationLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xffF44336),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              context.l10n.loadingMoreVisitors,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xff57636C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExportBottomSheet(
      BuildContext context, List<VisitorLog> visitorLogs) async {
    TextEditingController emailController = TextEditingController();
    TextEditingController nameController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    String? exportErrorMessage;
    bool isEmailFieldFocused = false;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final storedEmail = prefs.getString('email') ?? '';
    emailController.text = storedEmail;

    final exportFormKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      transitionAnimationController: AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: Navigator.of(context),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
                minHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              margin: const EdgeInsets.only(top: 60),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Enhanced drag handle
                  const SizedBox(height: 12),
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Enhanced header with gradient background
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xffF44336).withOpacity(0.08),
                          const Color(0xffff5722).withOpacity(0.03),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Enhanced icon section
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xffF44336).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xffF44336).withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.download_rounded,
                            color: Color(0xffF44336),
                            size: 24,
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Header text section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.l10n.exportVisitorLogs,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xff212427),
                                      fontSize: 20,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.downloadLogsForDateRange,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xff57636C),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                            ],
                          ),
                        ),

                        // Enhanced close button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(
                                  0xffF44336), // Changed from Color(0xff57636C) to red
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Inline error banner (if any)
                  if (exportErrorMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFCDD2)),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Color(0xFFD32F2F)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                exportErrorMessage ?? '',
                                style: const TextStyle(
                                  color: Color(0xFFD32F2F),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),

                  // Enhanced form content
                  Expanded(
                    child: Form(
                      key: exportFormKey,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        child: Column(
                          children: [
                            // Enhanced email field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 4, bottom: 8),
                                  child: Text(
                                    context.l10n.emailAddress,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                Focus(
                                  onFocusChange: (hasFocus) {
                                    setState(() {
                                      isEmailFieldFocused = hasFocus;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isEmailFieldFocused
                                            ? const Color(0xffF44336)
                                            : Colors.grey[300]!,
                                        width: isEmailFieldFocused ? 1 : 1.5,
                                      ),
                                    ),
                                    child: TextFormField(
                                      controller: emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      cursorColor: const Color(0xffF44336),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                      decoration: InputDecoration(
                                        hintText:
                                            context.l10n.enterEmailForExport,
                                        hintStyle: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.all(8),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xffF44336)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.email_outlined,
                                            color: Color(0xffF44336),
                                            size: 20,
                                          ),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value!.isEmpty) {
                                          return context.l10n.pleaseEnterEmail;
                                        }
                                        if (!value.contains('@')) {
                                          return context
                                              .l10n.pleaseEnterValidEmail;
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Enhanced date selection section
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 4, bottom: 8),
                                  child: Text(
                                    context.l10n.dateRange,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),

                                // From Date Field
                                FormField<DateTime>(
                                  validator: (value) {
                                    if (startDate == null) {
                                      return context.l10n.pleaseSelectStartDate;
                                    }
                                    return null;
                                  },
                                  builder: (fieldState) {
                                    return Column(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: fieldState.hasError
                                                  ? Colors.red[300]!
                                                  : Colors.grey[300]!,
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey
                                                    .withOpacity(0.08),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: InkWell(
                                            onTap: () async {
                                              FocusScope.of(context)
                                                  .unfocus(); // Close keyboard
                                              final DateTime? picked =
                                                  await showDatePicker(
                                                context: context,
                                                initialDate:
                                                    startDate ?? DateTime.now(),
                                                firstDate: DateTime(2000),
                                                lastDate: DateTime.now(),
                                                builder: (BuildContext context,
                                                    Widget? child) {
                                                  return Theme(
                                                    data: ThemeData.light()
                                                        .copyWith(
                                                      colorScheme:
                                                          const ColorScheme
                                                              .light(
                                                        primary:
                                                            Color(0xffF44336),
                                                        onPrimary: Colors.white,
                                                        surface: Colors.white,
                                                        onSurface:
                                                            Colors.black87,
                                                        secondary:
                                                            Color(0xffF44336),
                                                        onSecondary:
                                                            Colors.white,
                                                      ),
                                                      textButtonTheme:
                                                          TextButtonThemeData(
                                                        style: TextButton
                                                            .styleFrom(
                                                          foregroundColor:
                                                              const Color(
                                                                  0xffF44336),
                                                          textStyle:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                      ),
                                                      dialogTheme:
                                                          const DialogThemeData(
                                                        backgroundColor:
                                                            Colors.white,
                                                        elevation: 12,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.all(
                                                                  Radius
                                                                      .circular(
                                                                          16)),
                                                        ),
                                                      ),
                                                      datePickerTheme:
                                                          DatePickerThemeData(
                                                        backgroundColor:
                                                            Colors.white,
                                                        headerBackgroundColor:
                                                            const Color(
                                                                0xffF44336),
                                                        headerForegroundColor:
                                                            Colors.white,
                                                        dayStyle:
                                                            const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontSize: 16,
                                                        ),
                                                        weekdayStyle: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                        yearStyle:
                                                            const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontSize: 16,
                                                        ),
                                                        dayOverlayColor:
                                                            WidgetStateProperty
                                                                .resolveWith(
                                                                    (states) {
                                                          if (states.contains(
                                                              WidgetState
                                                                  .selected)) {
                                                            return const Color(
                                                                0xffF44336);
                                                          }
                                                          if (states.contains(
                                                              WidgetState
                                                                  .hovered)) {
                                                            return const Color(
                                                                    0xffF44336)
                                                                .withOpacity(
                                                                    0.1);
                                                          }
                                                          return null;
                                                        }),
                                                        todayBorder:
                                                            const BorderSide(
                                                          color:
                                                              Color(0xffF44336),
                                                          width: 2,
                                                        ),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(16),
                                                        ),
                                                        elevation: 8,
                                                      ),
                                                    ),
                                                    child: child!,
                                                  );
                                                },
                                              );
                                              if (picked != null) {
                                                setState(() {
                                                  startDate = picked;
                                                  if (endDate != null &&
                                                      startDate!
                                                          .isAfter(endDate!)) {
                                                    endDate = null;
                                                  }
                                                  fieldState.didChange(picked);
                                                });
                                              }
                                            },
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                              0xffF44336)
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: const Icon(
                                                      Icons
                                                          .calendar_today_outlined,
                                                      color: Color(0xffF44336),
                                                      size: 20,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          context.l10n.fromDate,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: Colors
                                                                .grey[600],
                                                            letterSpacing: 0.2,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(
                                                          startDate != null
                                                              ? DateFormat(
                                                                      'MMM dd, yyyy')
                                                                  .format(
                                                                      startDate!)
                                                              : context.l10n
                                                                  .selectStartDate,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: startDate !=
                                                                    null
                                                                ? Colors.black87
                                                                : Colors
                                                                    .grey[400],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons
                                                        .arrow_forward_ios_rounded,
                                                    color: Colors.grey[400],
                                                    size: 18,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (fieldState.hasError)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 8, left: 12),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                fieldState.errorText!,
                                                style: TextStyle(
                                                  color: Colors.red[600],
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),

                                const SizedBox(height: 16),

                                // To Date Field
                                FormField<DateTime>(
                                  validator: (value) {
                                    if (endDate == null) {
                                      return context.l10n.pleaseSelectEndDate;
                                    }
                                    if (startDate != null &&
                                        endDate!.isBefore(startDate!)) {
                                      return context
                                          .l10n.endDateCannotBeEarlier;
                                    }
                                    return null;
                                  },
                                  builder: (fieldState) {
                                    return Column(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: fieldState.hasError
                                                  ? Colors.red[300]!
                                                  : Colors.grey[300]!,
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey
                                                    .withOpacity(0.08),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: InkWell(
                                            onTap: () async {
                                              FocusScope.of(context)
                                                  .unfocus(); // Close keyboard
                                              final DateTime? picked =
                                                  await showDatePicker(
                                                context: context,
                                                initialDate:
                                                    endDate ?? DateTime.now(),
                                                firstDate:
                                                    startDate ?? DateTime(2000),
                                                lastDate: DateTime.now(),
                                                builder: (BuildContext context,
                                                    Widget? child) {
                                                  return Theme(
                                                    data: ThemeData.light()
                                                        .copyWith(
                                                      colorScheme:
                                                          const ColorScheme
                                                              .light(
                                                        primary:
                                                            Color(0xffF44336),
                                                        onPrimary: Colors.white,
                                                        surface: Colors.white,
                                                        onSurface:
                                                            Colors.black87,
                                                        secondary:
                                                            Color(0xffF44336),
                                                        onSecondary:
                                                            Colors.white,
                                                      ),
                                                      textButtonTheme:
                                                          TextButtonThemeData(
                                                        style: TextButton
                                                            .styleFrom(
                                                          foregroundColor:
                                                              const Color(
                                                                  0xffF44336),
                                                          textStyle:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                      ),
                                                      dialogTheme:
                                                          const DialogThemeData(
                                                        backgroundColor:
                                                            Colors.white,
                                                        elevation: 12,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.all(
                                                                  Radius
                                                                      .circular(
                                                                          16)),
                                                        ),
                                                      ),
                                                      datePickerTheme:
                                                          DatePickerThemeData(
                                                        backgroundColor:
                                                            Colors.white,
                                                        headerBackgroundColor:
                                                            const Color(
                                                                0xffF44336),
                                                        headerForegroundColor:
                                                            Colors.white,
                                                        dayStyle:
                                                            const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontSize: 16,
                                                        ),
                                                        weekdayStyle: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                        yearStyle:
                                                            const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontSize: 16,
                                                        ),
                                                        dayOverlayColor:
                                                            WidgetStateProperty
                                                                .resolveWith(
                                                                    (states) {
                                                          if (states.contains(
                                                              WidgetState
                                                                  .selected)) {
                                                            return const Color(
                                                                0xffF44336);
                                                          }
                                                          if (states.contains(
                                                              WidgetState
                                                                  .hovered)) {
                                                            return const Color(
                                                                    0xffF44336)
                                                                .withOpacity(
                                                                    0.1);
                                                          }
                                                          return null;
                                                        }),
                                                        todayBorder:
                                                            const BorderSide(
                                                          color:
                                                              Color(0xffF44336),
                                                          width: 2,
                                                        ),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(16),
                                                        ),
                                                        elevation: 8,
                                                      ),
                                                    ),
                                                    child: child!,
                                                  );
                                                },
                                              );
                                              if (picked != null) {
                                                setState(() {
                                                  endDate = picked;
                                                  fieldState.didChange(picked);
                                                });
                                              }
                                            },
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                              0xffF44336)
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: const Icon(
                                                      Icons
                                                          .calendar_today_outlined,
                                                      color: Color(0xffF44336),
                                                      size: 20,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          context.l10n.toDate,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: Colors
                                                                .grey[600],
                                                            letterSpacing: 0.2,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(
                                                          endDate != null
                                                              ? DateFormat(
                                                                      'MMM dd, yyyy')
                                                                  .format(
                                                                      endDate!)
                                                              : context.l10n
                                                                  .selectEndDate,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: endDate !=
                                                                    null
                                                                ? Colors.black87
                                                                : Colors
                                                                    .grey[400],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons
                                                        .arrow_forward_ios_rounded,
                                                    color: Colors.grey[400],
                                                    size: 18,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (fieldState.hasError)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 8, left: 12),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                fieldState.errorText!,
                                                style: TextStyle(
                                                  color: Colors.red[600],
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),

                            // Enhanced export button with black-to-grey gradient
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: isLoading
                                  ? Container(
                                      height: 56,
                                      alignment: Alignment.center,
                                      child: const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: DashboardLoaderIcon(
                                          color: Color(0xff2C2C2C),
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: double.infinity,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Color(0xff2C2C2C), // Black
                                            Color(0xff6E6E6E), // Grey
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          if (startDate == null) {
                                            _showEnhancedErrorToast(
                                              title:
                                                  context.tr('Date Required'),
                                              message: context.tr(
                                                'Please select a start date to proceed',
                                              ),
                                              icon:
                                                  Icons.calendar_today_rounded,
                                            );
                                            return;
                                          }
                                          if (endDate == null) {
                                            _showEnhancedErrorToast(
                                              title:
                                                  context.tr('Date Required'),
                                              message: context.tr(
                                                'Please select an end date to proceed',
                                              ),
                                              icon:
                                                  Icons.calendar_today_rounded,
                                            );
                                            return;
                                          }
                                          if (exportFormKey.currentState!
                                              .validate()) {
                                            await prefs.setString(
                                                'email', emailController.text);

                                            final formattedFromDate =
                                                DateFormat('yyyy-MM-dd')
                                                    .format(startDate!);
                                            final formattedToDate =
                                                DateFormat('yyyy-MM-dd')
                                                    .format(endDate!);

                                            final gateProvider =
                                                Provider.of<GateProvider>(
                                                    context,
                                                    listen: false);
                                            final selectedGate =
                                                gateProvider.selectedGate;
                                            final email =
                                                emailController.text.trim();

                                            final visitorData = {
                                              "company_id": societyId,
                                              "name": nameController.text,
                                              "to_mail": email,
                                              "from_date": formattedFromDate,
                                              "to_date": formattedToDate,
                                              "in_gate": selectedGateName,
                                            };

                                            // Add is_checkout based on the initiating card
                                            if (_resolvedVisitorLogType(
                                                    widget.id) ==
                                                'Visitor In') {
                                              visitorData['is_checkout'] =
                                                  false;
                                            } else if (_resolvedVisitorLogType(
                                                    widget.id) ==
                                                'Visitor Out') {
                                              visitorData['is_checkout'] = true;
                                            }

                                            try {
                                              await _showExportProgressDialog(
                                                onExecute: () async {
                                                  await remoteDataSource
                                                      .exportLogs(visitorData);
                                                },
                                                title: context.tr(
                                                  'exportLogsProgressTitle',
                                                ),
                                              );

                                              // Close bottom sheet after progress completes
                                              Navigator.pop(context);
                                              _showExportSuccessDialog(
                                                title: context.tr(
                                                  'exportLogsSuccessTitle',
                                                ),
                                                message: context.tr(
                                                  'exportLogsSuccessMessage',
                                                ),
                                                icon:
                                                    Icons.download_done_rounded,
                                              );
                                            } catch (e) {
                                              final msg = e.toString();
                                              if (msg
                                                  .contains('No data found')) {
                                                _showNoDataFoundDialog();
                                              } else {
                                                _showExportErrorDialog(
                                                  'Failed to export logs as no data was recorded for the selected date. Try selecting another date.',
                                                );
                                              }
                                            }
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          elevation: 0,
                                        ),
                                        icon: const Icon(
                                          Icons.download_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        label: Text(
                                          context.tr('Export Logs'),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Shows a determinate progress dialog while export runs and updates percentage.
  Future<void> _showExportProgressDialog(
      {required Future<void> Function() onExecute,
      String title = 'Exporting...'}) async {
    int progress = 0;
    Timer? timer;
    bool completed = false;
    void Function(void Function())? dialogSetState;
    Object? capturedError;

    final dialogFuture = showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            dialogSetState ??= setState;
            // Start timer once when dialog builds first time
            timer ??= Timer.periodic(const Duration(milliseconds: 200), (t) {
              if (completed) return;
              setState(() {
                // Smoothly progress up to 90% while waiting for server
                if (progress < 90) {
                  progress += 2; // ~9s to reach 90%
                  if (progress > 90) progress = 90;
                }
              });
            });

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.download_rounded,
                            color: Color(0xffF44336)),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF212427),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: progress / 100.0,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF4CAF50)),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "$progress%",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF57636C),
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

    // Start export concurrently and drive dialog to 100% upon completion
    unawaited(() async {
      try {
        await onExecute();
        completed = true;
        if (dialogSetState != null) {
          dialogSetState!(() {
            progress = 100;
          });
        }
        await Future.delayed(const Duration(milliseconds: 400));
      } catch (e) {
        capturedError = e;
      } finally {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        timer?.cancel();
      }
    }());

    await dialogFuture.whenComplete(() {
      timer?.cancel();
    });

    if (capturedError != null) {
      // Rethrow to let caller show error toast
      throw capturedError!;
    }
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: Colors.red)),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Close dialog
              child: Text(AppLocalizations.of(context).ok),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateField(BuildContext context,
      {required String label, DateTime? date, required String placeholder}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 20),
              const SizedBox(width: 8),
              Text(
                date != null
                    ? DateFormat('MMM dd, yyyy').format(date)
                    : placeholder,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void showSuccessDialog({
    required BuildContext context,
    required String title,
    required String message,
    VoidCallback? onDismiss,
  }) {
    showGeneralDialog(
      context: context,
      pageBuilder: (_, __, ___) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity:
                Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 8,
              title: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.5),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
                )),
                child: Row(
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1500),
                      tween: Tween<double>(begin: 0, end: 2 * 3.14159),
                      builder: (context, value, child) => Transform.rotate(
                        angle: value,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green.shade600,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              content: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
                )),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            // color: Colors.green,
                            height: 1.5,
                          ),
                    ),
                  ),
                ),
              ),
              actions: [
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
                  )),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              Colors.black, // Set the background color to black
                          foregroundColor:
                              Colors.white, // Set the text color to white
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onDismiss?.call();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(context.tr('OK')),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 500),
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
    );
  }

  void _showLogBookConfigBottomSheet(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Enhanced drag handle
                  const SizedBox(height: 12),
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Enhanced header with gradient background
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xffF44336).withOpacity(0.08),
                          const Color(0xffff5722).withOpacity(0.03),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Compact icon section
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xffF44336).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xffF44336).withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.filter_list_rounded,
                            color: Color(0xffF44336),
                            size: 24,
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Simple label section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.tr('Filter Options'),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xff212427),
                                      fontSize: 20,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr('Choose your preferred view'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xff57636C),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Enhanced content area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(top: 16),
                        itemCount: widget.logList.length,
                        itemBuilder: (context, index) {
                          final filterOption = widget.logList[index];
                          final isSelected = selectedId == filterOption;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    selectedId = filterOption;
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xffF44336)
                                          : Colors.grey[200]!,
                                      width: isSelected ? 1 : 0.8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isSelected
                                            ? const Color(0xffF44336)
                                                .withOpacity(0.1)
                                            : Colors.grey.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Filter option icon with background
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: const Color(0xffF44336)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          _getFilterIcon(filterOption),
                                          color: const Color(0xffF44336),
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Filter option information
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _getLocalizedVisitorLogTitle(
                                                context,
                                                filterOption,
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        const Color(0xff212427),
                                                    fontSize: 18,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _getFilterDescription(
                                                  filterOption),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        const Color(0xff57636C),
                                                    fontSize: 14,
                                                    height: 1.3,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Enhanced green toggle switch
                                      Transform.scale(
                                        scale: 1.2,
                                        child: Switch(
                                          value: isSelected,
                                          onChanged: (value) {
                                            setState(() {
                                              selectedId = filterOption;
                                            });
                                          },
                                          activeThumbColor: Colors.white,
                                          activeTrackColor:
                                              Colors.green.shade600,
                                          inactiveThumbColor: Colors.grey[300],
                                          inactiveTrackColor: Colors.grey[200],
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Enhanced apply filter button with black to grey gradient
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xff2C2C2C), // Dark black/charcoal
                            Color(0xff6E6E6E), // Medium grey
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            widget.id = selectedId ?? widget.id;
                          });
                          Navigator.pop(context);
                          Navigator.pushReplacement(
                            context,
                            PageTransition(
                              type: PageTransitionType.bottomToTop,
                              child: VisitorLogView(
                                id: widget.id,
                                logList: widget.logList,
                                selectedBuilding: widget.selectedBuilding,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        icon: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          context.tr('Apply Filter'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
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
    );
  }

  // Helper methods for filter options
  IconData _getFilterIcon(String filterOption) {
    switch (filterOption.toLowerCase()) {
      case 'in out book':
        return Icons.book_rounded;
      case 'visitor in':
        return Icons.login_rounded;
      case 'visitor out':
        return Icons.logout_rounded;
      case 'cards':
        return Icons.badge_rounded;
      default:
        return Icons.filter_list_rounded;
    }
  }

  String _getFilterDescription(String filterOption) {
    switch (filterOption.toLowerCase()) {
      case 'in out book':
        return context.tr('View all visitor entries and exits');
      case 'visitor in':
        return context.tr('Show only checked-in visitors');
      case 'visitor out':
        return context.tr('Show only checked-out visitors');
      case 'cards':
        return context.tr('View visitors with card access');
      default:
        return context.tr('Filter visitor log entries');
    }
  }

  // Add a method to update today's counts
  Future<void> _updateTodayLogsCount() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt('todayLogsCount') ?? 0;
    await prefs.setInt('todayLogsCount', currentCount - 1);

    final currentCheckoutCount = prefs.getInt('todayCheckoutLogsCount') ?? 0;
    await prefs.setInt('todayCheckoutLogsCount', currentCheckoutCount + 1);
  }

  /// Enhanced success toast with premium styling
  void _showEnhancedSuccessToast({
    required String title,
    required String message,
    required IconData icon,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              // Enhanced icon container with gradient background
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF4CAF50), // Green
                      Color(0xFF2E7D32), // Darker green
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Enhanced text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title with enhanced typography
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Message with better readability
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Success indicator
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF1B5E20), // Dark green background
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        elevation: 12,
        action: SnackBarAction(
          label: context.tr('Dismiss'),
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Enhanced export success dialog with premium styling
  void _showExportSuccessDialog({
    required String title,
    required String message,
    required IconData icon,
  }) {
    showDialog(
      context: context,
      barrierDismissible:
          false, // Dialog cannot be dismissed by tapping outside
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success Icon with gradient background
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF4CAF50), // Green
                          Color(0xFF2E7D32), // Darker green
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title with enhanced typography
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF212427), // OneGate primary text color
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Message with better readability
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF57636C), // OneGate muted text color
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // OK Button with OneGate theme
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xff2C2C2C), // OneGate black
                          Color(0xff6E6E6E), // OneGate grey
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff2C2C2C).withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: const Color(0xff6E6E6E).withOpacity(0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        context.tr('OK'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Shows a blocking modal dialog for "No data found"
  void _showNoDataFoundDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.info_outline_rounded, color: Color(0xFFEF6C00)),
                    SizedBox(width: 8),
                    Text(
                      'No data found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF212427),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    'No data found for the selected filters. Try a different date range or card.',
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF57636C),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(context.tr('OK')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Shows a blocking modal dialog for generic export errors with OK button
  void _showExportErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Error Icon with gradient background (match success UI)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFF7043), // Orange
                          Color(0xFFD32F2F), // Red
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD32F2F).withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title (match success UI typography)
                  Text(
                    context.tr('Export Failed'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF212427),
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Message (match success UI body style)
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF57636C),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // OK Button with same sizing as success dialog
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xffF44336), // OneGate red
                          Color(0xffD32F2F), // OneGate dark red
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        context.tr('OK'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Enhanced error toast
  void _showEnhancedErrorToast({
    required String title,
    required String message,
    IconData? icon,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon ?? Icons.error_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xffF44336),
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

  // Build "no more visitors to load" message widget
  Widget _buildNoMoreVisitorsMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr('No more visitors to load'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Enhanced empty state for search results
  Widget _buildEnhancedEmptySearchState() {
    final isTablet = MediaQuery.of(context).size.width > 600;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 40 : 24,
          vertical: isTablet ? 24 : 16,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardMaxWidth = isTablet ? 560.0 : constraints.maxWidth;
            final cardMinWidth = isTablet ? 460.0 : 300.0;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: cardMaxWidth,
                minWidth: cardMinWidth.clamp(0, cardMaxWidth).toDouble(),
              ),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 44 : 32,
                    vertical: isTablet ? 40 : 30,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: isTablet ? 100 : 80,
                        height: isTablet ? 100 : 80,
                        decoration: BoxDecoration(
                          color: const Color(0xffF44336).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.search_off_rounded,
                          color: const Color(0xffF44336),
                          size: isTablet ? 42 : 34,
                        ),
                      ),
                      SizedBox(height: isTablet ? 28 : 22),
                      Text(
                        context.tr('No Visitors Found'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          color: Color(0xff212427),
                        ),
                      ),
                      SizedBox(height: isTablet ? 14 : 10),
                      Text(
                        context.tr(
                          'No visitors match "{query}". Try a different keyword.',
                          params: {'query': _searchText ?? ''},
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Enhanced empty state for no visitors today
  Widget _buildEnhancedEmptyVisitorsState() {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final descriptionText = _resolvedVisitorLogType(widget.id) == 'Visitor Out'
        ? context.tr('visitorEmptyExitsQuietMessage')
        : context.tr('visitorEmptyEntriesQuietMessage');
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 40 : 24,
          vertical: isTablet ? 24 : 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 560 : 420,
            minWidth: isTablet ? 460 : 300,
          ),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 44 : 32,
                vertical: isTablet ? 40 : 30,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: isTablet ? 100 : 80,
                    height: isTablet ? 100 : 80,
                    decoration: BoxDecoration(
                      color: const Color(0xffF44336).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.groups_outlined,
                      color: const Color(0xffF44336),
                      size: isTablet ? 42 : 34,
                    ),
                  ),
                  SizedBox(height: isTablet ? 28 : 22),
                  Text(
                    context.tr('No visitors yet today'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isTablet ? 24 : 21,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff212427),
                    ),
                  ),
                  SizedBox(height: isTablet ? 14 : 10),
                  Text(
                    descriptionText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Helper widget for search tips
  Widget _buildSearchTip(String tip) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xffF44336).withOpacity(0.6),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            tip,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  /// Helper widget for feature items
  Widget _buildFeatureItem(IconData icon, String label, bool isTablet) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 10 : 8),
            decoration: BoxDecoration(
              color: const Color(0xffF44336).withOpacity(0.1),
              borderRadius: BorderRadius.circular(isTablet ? 10 : 8),
            ),
            child: Icon(
              icon,
              color: const Color(0xffF44336),
              size: isTablet ? 24 : 20,
            ),
          ),
          SizedBox(height: isTablet ? 10 : 8),
          Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  String _getLocalizedVisitorLogTitle(BuildContext context, String id) {
    switch (_resolvedVisitorLogType(id)) {
      case 'In Out Book':
        return context.l10n.visitorLogTitleInOutBook;
      case 'Visitor In':
        return context.l10n.visitorLogTitleVisitorIn;
      case 'Visitor Out':
        return context.l10n.visitorLogTitleVisitorOut;
      case 'Cards':
        return context.l10n.visitorLogTitleCards;
      default:
        return context.l10n.visitorLogTitleDefault;
    }
  }
}

class VisitorLogItem extends StatefulWidget {
  final VisitorLog visitorLog;
  final Function onCheckOut;
  final bool visitorCardEntryEnabled;
  final bool isVisitorCardsView;
  final VoidCallback? onCardAssigned;

  const VisitorLogItem({
    Key? key,
    required this.visitorLog,
    required this.onCheckOut,
    required this.visitorCardEntryEnabled,
    this.isVisitorCardsView = false,
    this.onCardAssigned,
  }) : super(key: key);

  @override
  State<VisitorLogItem> createState() => _VisitorLogItemState();
}

class _VisitorLogItemState extends State<VisitorLogItem> {
  final bool _hasCallSupport = true;
  Future<void>? _launched;

  @override
  void initState() {
    log("called..............${widget.visitorLog.visitor!.name} ${widget.visitorLog.visitor_check_in}");
    super.initState();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context) {
    String unitList = '';

    if (widget.visitorLog.visitor_building_assignment != null &&
        widget.visitorLog.visitor_building_assignment!.isNotEmpty) {
      unitList = widget.visitorLog.visitor_building_assignment!
          .expand((assignment) => assignment.unit_id ?? [])
          .map((unit) => unit.toString())
          .join(', ');
    }

    // Debug logging for initiated_from field
    if (widget.visitorLog.initiated_from != null) {
      print(
          '🔍 [DEBUG] VisitorLogItem - initiated_from: ${widget.visitorLog.initiated_from}');
      print(
          '🔍 [DEBUG] VisitorLogItem - visitor name: ${widget.visitorLog.visitor?.name}');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          Card(
            elevation: widget.isVisitorCardsView ? 0 : 5,
            shadowColor: widget.isVisitorCardsView
                ? Colors.transparent
                : Colors.black.withOpacity(0.24),
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VisitorDetailsScreen(
                          image: widget.visitorLog.visitor!.visitor_image,
                          unitList: unitList,
                          visitorLog: widget.visitorLog,
                          onCardAssigned: widget.onCardAssigned,
                        ),
                      ),
                    );
                  },
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundImage: widget.visitorLog.visitor!.visitor_image!
                                  .isNotEmpty &&
                              widget.visitorLog.visitor!.visitor_image != null
                          ? NetworkImage(
                              widget.visitorLog.visitor!.visitor_image ?? "")
                          : NetworkImage(
                              'https://images.unsplash.com/photo-1731778572747-315c9089bc69?q=80&w=2940&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D'),
                      child: widget.visitorLog.visitor!.visitor_image!.isEmpty
                          ? Text(
                              widget.visitorLog.visitor!.name!.isNotEmpty
                                  ? widget.visitorLog.visitor!.name![0]
                                  : 'G',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xffF44336),
                                  ),
                            )
                          : null,
                    ),
                  ),
                  title: Text(
                    widget.visitorLog.visitor!.name ?? 'Visitor Name',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff212427),
                          fontSize: 16,
                          letterSpacing: 0.1,
                        ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xffF44336).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      const Color(0xffF44336).withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                _getPurposeIcon(widget
                                    .visitorLog.visitor_purpose_Category_name),
                                color: const Color(0xffF44336),
                                size: 15,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Flexible(
                              child: Text(
                                "${widget.visitorLog.visitor_purpose_Category_name != null ? context.trPurposeCategory(widget.visitorLog.visitor_purpose_Category_name!) : "N/A"} ${_getUnitText()}",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontSize: 14,
                                      color: const Color(0xff57636C),
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                      height: 1.4,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(
                  indent: 20,
                  endIndent: 20,
                  height: 24,
                  thickness: 1,
                  color: Colors.grey.shade200,
                ),
                Container(
                  padding: const EdgeInsets.only(
                      bottom: 16.0, top: 12, left: 20, right: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Tooltip(
                        message: widget.visitorLog.visitor_check_in != null
                            ? DateFormat('dd-MM-yyyy hh:mm a')
                                .format(widget.visitorLog.visitor_check_in!)
                            : "No check-in time",
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.green.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Symbols.directions_walk_rounded,
                                color: Colors.green.shade600,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.visitorLog.visitor_check_in != null
                                    ? Utils.convertDateTimeFormat(
                                        widget.visitorLog.visitor_check_in!)
                                    : "N/A",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      letterSpacing: 0.3,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Self Entry Badge for other self entry methods
                      if (widget.visitorLog.initiated_from == "self_entry")
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xff4CAF50).withOpacity(0.1),
                                const Color(0xff2E7D32).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xff4CAF50),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.smartphone,
                                color: const Color(0xff4CAF50),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Self Entry",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: const Color(0xff4CAF50),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                      letterSpacing: 0.2,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      // Show visitor ID card icon + number only when card number exists AND visitor card entry is enabled
                      (widget.visitorLog.visitor_card_number != null &&
                              widget
                                  .visitorLog.visitor_card_number!.isNotEmpty &&
                              widget.visitorCardEntryEnabled)
                          ? Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                vertical: 2,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: const [
                                    Color.fromRGBO(255, 236, 158, 0.8),
                                    Color.fromRGBO(255, 190, 168, 0.8),
                                  ],
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Color.fromRGBO(255, 190, 168, 1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  widget.visitorLog.visitor_card_number != null
                                      ? Lottie.asset(
                                          'assets/json/idcard.json',
                                          width: 30,
                                          height: 30,
                                          fit: BoxFit.cover,
                                        )
                                      : Icon(
                                          Symbols.car_tag_rounded,
                                          size: 30,
                                          // color: Colors.red, // Optional color for the icon
                                        ),
                                  const SizedBox(width: 5),
                                  Text(
                                    widget.visitorLog.visitor_card_number !=
                                            null
                                        ? widget.visitorLog.visitor_card_number!
                                        : 'N/A',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .copyWith(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                  ),
                                ],
                              ),
                            )
                          : Spacer(),
                      // Show Assign Card when entry is not from gatekeeper, no card is set, and visitor card entry is enabled
                      (widget.visitorLog.initiated_from != "gatekeeper") &&
                              (widget.visitorLog.visitor_card_number == null ||
                                  widget.visitorLog.visitor_card_number!
                                      .isEmpty) &&
                              widget.visitorCardEntryEnabled
                          ? GestureDetector(
                              onTap: () {
                                if (widget.visitorLog.visitor_id == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.tr(
                                          'Error: Visitor ID not found',
                                        ),
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                showDialog(
                                  context: context,
                                  builder: (context) => AssignCardPopup(
                                    visitorId: widget.visitorLog.visitor_id!,
                                    visitorName:
                                        widget.visitorLog.visitor?.name ??
                                            'Visitor',
                                    onCardAssigned: (cardNumber) {
                                      // Refresh the list to show updated card
                                      setState(() {});
                                      // Trigger visitor log list refresh
                                      if (widget.onCardAssigned != null) {
                                        widget.onCardAssigned!();
                                      }
                                    },
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xff212427),
                                      Color(0xff57636C)
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.credit_card,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      context.tr('Assign Card'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : (widget.visitorLog.visitor_check_out
                                      .toString()
                                      .isEmpty ||
                                  widget.visitorLog.visitor_check_out
                                          .toString() ==
                                      'null')
                              ? ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xffF44336),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        final isTablet =
                                            MediaQuery.of(context).size.width >
                                                768;
                                        return Dialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Container(
                                            width: isTablet
                                                ? 500
                                                : double.infinity,
                                            constraints: BoxConstraints(
                                              maxWidth: isTablet
                                                  ? 500
                                                  : MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.9,
                                              maxHeight: MediaQuery.of(context)
                                                      .size
                                                      .height *
                                                  0.8,
                                            ),
                                            padding: EdgeInsets.all(
                                                isTablet ? 32 : 24),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  context
                                                      .tr('Confirm Checkout'),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge
                                                      ?.copyWith(
                                                        fontSize:
                                                            isTablet ? 24 : 20,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: const Color(
                                                            0xff212427),
                                                      ),
                                                ),
                                                SizedBox(
                                                    height: isTablet ? 24 : 20),
                                                Container(
                                                  padding: EdgeInsets.all(
                                                      isTablet ? 16 : 12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    border: Border.all(
                                                      color: Colors.amber[100]!,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .info_outline_rounded,
                                                        color:
                                                            Colors.amber[700],
                                                        size:
                                                            isTablet ? 24 : 20,
                                                      ),
                                                      SizedBox(
                                                          width: isTablet
                                                              ? 16
                                                              : 12),
                                                      Expanded(
                                                        child: Text(
                                                          context.tr(
                                                            'checkoutPermanentInfo',
                                                          ),
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color: Colors
                                                                    .amber[800],
                                                                fontSize:
                                                                    isTablet
                                                                        ? 15
                                                                        : 13,
                                                                height: 1.4,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(
                                                    height: isTablet ? 32 : 28),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: OutlinedButton(
                                                        style: OutlinedButton
                                                            .styleFrom(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                            vertical: isTablet
                                                                ? 16
                                                                : 14,
                                                          ),
                                                          side:
                                                              const BorderSide(
                                                            color: Color(
                                                                0xff57636C),
                                                            width: 1,
                                                          ),
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                          ),
                                                        ),
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context),
                                                        child: Text(
                                                          context.tr('cancel'),
                                                          style: TextStyle(
                                                            color: const Color(
                                                                0xff57636C),
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: isTablet
                                                                ? 16
                                                                : 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                        width:
                                                            isTablet ? 16 : 12),
                                                    Expanded(
                                                      child: StatefulBuilder(
                                                        builder: (context,
                                                            setState) {
                                                          bool isCheckingOut =
                                                              false;
                                                          return ElevatedButton(
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              backgroundColor:
                                                                  const Color(
                                                                      0xffF44336),
                                                              foregroundColor:
                                                                  Colors.white,
                                                              elevation: 0,
                                                              padding: EdgeInsets
                                                                  .symmetric(
                                                                vertical:
                                                                    isTablet
                                                                        ? 16
                                                                        : 14,
                                                              ),
                                                              shape:
                                                                  RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                            ),
                                                            onPressed:
                                                                isCheckingOut
                                                                    ? null
                                                                    : () async {
                                                                        setState(() =>
                                                                            isCheckingOut =
                                                                                true);
                                                                        await Future.delayed(const Duration(
                                                                            milliseconds:
                                                                                800));
                                                                        Navigator.of(context)
                                                                            .pop();
                                                                        widget
                                                                            .onCheckOut();
                                                                        ScaffoldMessenger.of(context)
                                                                            .showSnackBar(
                                                                          SnackBar(
                                                                            content:
                                                                                Row(
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
                                                                                    size: 20,
                                                                                  ),
                                                                                ),
                                                                                const SizedBox(width: 12),
                                                                                Expanded(
                                                                                  child: Text(
                                                                                    context.tr(
                                                                                      'Visitor checked out successfully',
                                                                                    ),
                                                                                    style: TextStyle(color: Colors.white),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                            backgroundColor:
                                                                                Colors.green,
                                                                            behavior:
                                                                                SnackBarBehavior.floating,
                                                                            margin:
                                                                                const EdgeInsets.all(16),
                                                                            duration:
                                                                                const Duration(milliseconds: 3000),
                                                                            elevation:
                                                                                8,
                                                                          ),
                                                                        );
                                                                      },
                                                            child: isCheckingOut
                                                                ? SizedBox(
                                                                    width:
                                                                        isTablet
                                                                            ? 24
                                                                            : 22,
                                                                    height:
                                                                        isTablet
                                                                            ? 24
                                                                            : 22,
                                                                    child:
                                                                        const DashboardLoaderIcon(
                                                                      valueColor: AlwaysStoppedAnimation<
                                                                              Color>(
                                                                          Colors
                                                                              .white),
                                                                      strokeWidth:
                                                                          2.5,
                                                                    ),
                                                                  )
                                                                : Text(
                                                                    context.tr(
                                                                        'confirm'),
                                                                    style:
                                                                        TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      fontSize:
                                                                          isTablet
                                                                              ? 16
                                                                              : 14,
                                                                      letterSpacing:
                                                                          0.3,
                                                                    ),
                                                                  ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  child: Text(
                                    context.tr('checkout'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                )
                              : Tooltip(
                                  message: widget
                                              .visitorLog.visitor_check_out !=
                                          null
                                      ? DateFormat('dd-MM-yyyy hh:mm a').format(
                                          widget.visitorLog.visitor_check_out!)
                                      : "No check-out time",
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffF44336)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xffF44336)
                                            .withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Symbols.directions_walk_rounded,
                                          color: const Color(0xffF44336),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          widget.visitorLog.visitor_check_out !=
                                                  null
                                              ? Utils.convertDateTimeFormat(
                                                  widget.visitorLog
                                                      .visitor_check_out!)
                                              : "N/A",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: const Color(0xffF44336),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                                letterSpacing: 0.3,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Positioned Pre-approved Badge for top right corner
          if (widget.visitorLog.initiated_from == "invited_guest" ||
              widget.visitorLog.initiated_from == "qr_code_scan" ||
              widget.visitorLog.initiated_from == "passcode_entry")
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: const [
                      Color(0xff4CAF50),
                      Color(0xff388E3C),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff4CAF50).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.how_to_reg,
                      color: Colors.white,
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      context.tr('Pre-approved'),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return "";
    return text
        .split(' ') // Split into words
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : word)
        .join(' '); // Join words back
  }

  IconData _getPurposeIcon(String? category) {
    switch (category?.toUpperCase()) {
      case "DELIVERY":
        return Icons.inventory_2_outlined;
      case "CABS":
        return Symbols.local_taxi;
      case "VENDOR":
        return Symbols.storefront;
      default:
        return Symbols.person;
    }
  }

  String _getUnitText() {
    // Check if visitor_building_assignment exists and has items
    if (widget.visitorLog.visitor_building_assignment == null ||
        widget.visitorLog.visitor_building_assignment!.isEmpty) {
      return ""; // Return empty string if no building assignment
    }

    // Check if the first building assignment has unit_id
    final firstAssignment =
        widget.visitorLog.visitor_building_assignment!.first;
    if (firstAssignment.unit_id == null || firstAssignment.unit_id!.isEmpty) {
      return ""; // Return empty string if no unit_id
    }

    // Return the unit_id with a dash prefix
    return "- ${firstAssignment.unit_id!.first}";
  }
}
