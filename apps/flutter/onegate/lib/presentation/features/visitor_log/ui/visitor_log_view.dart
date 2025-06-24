// ignore_for_file: prefer_const_constructors

import 'dart:developer';

import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
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
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/bloc/visitor_log_bloc.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/ui/visitor_Details.dart';
import 'package:flutter_onegate/utils/app_utils.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_onegate/presentation/widgets/building_dropdown.dart';

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

class _VisitorLogViewState extends State<VisitorLogView> {
  late String selectedId;
  String? _searchText = "";
  var selectedGateName;
  late FocusNode _searchFocusNode;
  String? selectedBuilding = "All Buildings";

  List<String> options = ['All', 'Today', 'This Week', 'This Month', 'Custom'];
  final gateStorage = GateStorage();
  final remoteDataSource = RemoteDataSource();
  var societyId;
  final ScrollController _scrollController = ScrollController();

  final VisitorLogBloc _visitorLogBloc = VisitorLogBloc(
    VisitorLogUsecase(
      VisitorLogRepositoryImpl(
        RemoteDataSource(),
      ),
    ),
  );

  @override
  void initState() {
    super.initState();
    selectedId = widget.id;

    switch (widget.id) {
      case "In Out Book":
        _visitorLogBloc.add(FetchVisitorLogEvent(
          Utils.getCurrentTime(),
          currentPage: 1,
          perPage: 20,
        ));
        break;
      case "Visitor In":
        _visitorLogBloc.add(FetchCheckInLogEvent(
          Utils.getCurrentTime(),
          currentPage: 1,
          perPage: 20,
        ));
        break;
      case "Cards":
        _visitorLogBloc.add(FetchCheckOutLogEvent(
          Utils.getCurrentTime(),
          currentPage: 1,
          perPage: 20,
        ));
        break;

      case "Visitor Out":
        _visitorLogBloc.add(FetchCheckOutLogEvent(Utils.getCurrentTime()));
        break;
    }
    _initializeSocietyId();
    getSelectedGate();
    _searchFocusNode = FocusNode();
    // _scrollController.addListener(() {
    //   if (_scrollController.position.pixels >=
    //           _scrollController.position.maxScrollExtent - 200 &&
    //       _visitorLogBloc.state is! VisitorLogLoadingMoreState) {
    //     final currentState = _visitorLogBloc.state;
    //     if (currentState is VisitorLogSuccessState) {
    //       _visitorLogBloc.add(LoadMoreVisitorLogsEvent(
    //         currentState.currentPage! + 1, // Pass next page
    //         40, // Number of items per page
    //       ));
    //     }
    //   }
    // });
    // _storeTodayLogsCount(context);
  }

  int current_page = 5;
  final int per_page = 20;

  @override
  void dispose() {
    _searchFocusNode.dispose();

    super.dispose();
  }

  Future<void> getSelectedGate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedGateName = prefs.getString('selected_gate');
    });
  }

  Future<void> _initializeSocietyId() async {
    societyId = await gateStorage.getSocietyId();
    log('Society ID: $societyId');
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final yesterday = today.subtract(Duration(days: 1));

    return BlocConsumer<VisitorLogBloc, VisitorLogState>(
      bloc: _visitorLogBloc,
      listenWhen: (previous, current) => current is VisitorLogActionState,
      buildWhen: (previous, current) => current is! VisitorLogActionState,
      listener: (context, state) {
        switch (state.runtimeType) {
          case VisitorLogCheckOutSuccessState:
            final successState = state as VisitorLogCheckOutSuccessState;
            if (successState.isCheckOut!) {
              _showEnhancedSuccessToast(
                title: 'Check-Out Successful',
                message: 'User has been checked out successfully',
                icon: Icons.logout_rounded,
              );
              _visitorLogBloc.add(FetchVisitorLogEvent(DateTime.now()));
            }
            break;
          case VisitorCheckInLogSuccessState:
            _visitorLogBloc.add(FetchCheckInLogEvent(Utils.getCurrentTime()));
            _showEnhancedSuccessToast(
              title: 'Check-Out Successful',
              message: 'Visitor has been checked out successfully',
              icon: Icons.logout_rounded,
            );
            break;
        }
      },
      builder: (context, state) {
        switch (state.runtimeType) {
          case VisitorLogLoadingState:
            return LoaderView();
          case VisitorLogSuccessState:
            final successState = state as VisitorLogSuccessState;
            final visitorLogs = (successState.visitorLogs ?? []).where((log) {
              if (widget.id == "Cards") {
                return log.visitor_card_number != null &&
                    log.visitor_card_number!.isNotEmpty;
              }
              return true; // Show all logs for other cases
            }).toList();
            List<VisitorLog> uniqueVisitorLogs = [];
            Set<String> checkInTimes = {};

            for (var log in visitorLogs) {
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

            // Filter visitors by name search
            List<VisitorLog> filteredVisitors = uniqueVisitorLogs
                .where((visitorLog) => visitorLog.visitor!.name!
                    .toLowerCase()
                    .contains(_searchText!.toLowerCase()))
                .toList();

            // Filter by selected building if not "All Buildings"
            if (selectedBuilding != null &&
                selectedBuilding != "All Buildings") {
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
                // isScrollable: false,
                hasBackButton: false,
                pageTitleWidget: Hero(
                  tag: 'page_title',
                  child: Text(
                    widget.id,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                actions: [
                  if (widget.id == "In Out Book")
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
                                  const Text(
                                    "Export",
                                    style: TextStyle(
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
                            hintText: 'Search Visitor',
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.search,
                            onFieldSubmitted: (value) {
                              log(value);
                            },
                            onChanged: (value) {
                              setState(() {
                                _searchText = value;
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
                                  onPressed: () {},
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
                      if (_searchText!.isNotEmpty && filteredVisitors.isEmpty)
                        _buildEnhancedEmptySearchState(),
                      if (filteredVisitors.isEmpty && _searchText!.isEmpty)
                        _buildEnhancedEmptyVisitorsState(),
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.only(bottom: 100),
                          physics: BouncingScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: groupedLogsList.length,
                          itemBuilder: (context, index) {
                            final dateKey = groupedLogsList[index].key;
                            final logsForDate = groupedLogsList[index].value;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 8.0),
                                  child: Chip(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          25), // Adjust the radius as needed
                                      side: BorderSide.none, // No border
                                    ),
                                    side: BorderSide.none,
                                    label: Text(
                                      DateFormat('MMM dd, yyyy')
                                          .format(DateTime.parse(dateKey)),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                Builder(builder: (context) {
                                  // No sorting - display logs as they come from the API response

                                  return ListView.builder(
                                    padding: EdgeInsets.zero,
                                    physics: NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: logsForDate.length,
                                    itemBuilder: (context, logIndex) {
                                      return VisitorLogItem(
                                        visitorLog: logsForDate[logIndex],
                                        onCheckOut: () {
                                          setState(() {
                                            logsForDate[logIndex]
                                                    .visitor_check_out =
                                                Utils.getCurrentTime();
                                            logsForDate[logIndex]
                                                .is_checked_out = true;
                                          });
                                          // Use add instead of emit
                                          _visitorLogBloc.add(CheckOutEvent(
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

  Future<void> _showExportBottomSheet(
      BuildContext context, List<VisitorLog> visitorLogs) async {
    TextEditingController emailController = TextEditingController();
    TextEditingController nameController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

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
                                'Export Visitor Logs',
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
                                'Download logs for specified date range',
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
                              color: Color(0xff57636C),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

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
                                    'Email Address',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: TextFormField(
                                    controller: emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    cursorColor: Colors.black,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "Enter email for export",
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
                                        return 'Please enter email';
                                      }
                                      if (!value.contains('@')) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
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
                                    'Date Range',
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
                                      return "Please select a start date";
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
                                                          const DialogTheme(
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
                                                            MaterialStateProperty
                                                                .resolveWith(
                                                                    (states) {
                                                          if (states.contains(
                                                              MaterialState
                                                                  .selected)) {
                                                            return const Color(
                                                                0xffF44336);
                                                          }
                                                          if (states.contains(
                                                              MaterialState
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
                                                          'From Date',
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
                                                              : 'Select start date',
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
                                      return "Please select an end date";
                                    }
                                    if (startDate != null &&
                                        endDate!.isBefore(startDate!)) {
                                      return "End date cannot be earlier than start date";
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
                                                          const DialogTheme(
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
                                                            MaterialStateProperty
                                                                .resolveWith(
                                                                    (states) {
                                                          if (states.contains(
                                                              MaterialState
                                                                  .selected)) {
                                                            return const Color(
                                                                0xffF44336);
                                                          }
                                                          if (states.contains(
                                                              MaterialState
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
                                                          'To Date',
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
                                                              : 'Select end date',
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
                                        child: CircularProgressIndicator(
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
                                              title: 'Date Required',
                                              message:
                                                  'Please select a start date to proceed',
                                              icon:
                                                  Icons.calendar_today_rounded,
                                            );
                                            return;
                                          }
                                          if (endDate == null) {
                                            _showEnhancedErrorToast(
                                              title: 'Date Required',
                                              message:
                                                  'Please select an end date to proceed',
                                              icon:
                                                  Icons.calendar_today_rounded,
                                            );
                                            return;
                                          }
                                          if (exportFormKey.currentState!
                                              .validate()) {
                                            setState(() {
                                              isLoading = true;
                                            });

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

                                            try {
                                              await remoteDataSource
                                                  .exportLogs(visitorData);
                                              setState(() {
                                                isLoading = false;
                                              });
                                              Navigator.pop(context);
                                              _showEnhancedSuccessToast(
                                                title: 'Export Successful',
                                                message:
                                                    'Visitor logs have been exported and sent to your email',
                                                icon:
                                                    Icons.download_done_rounded,
                                              );
                                            } catch (e) {
                                              setState(() {
                                                isLoading = false;
                                              });
                                              _showEnhancedErrorToast(
                                                title: 'Export Failed',
                                                message:
                                                    'Failed to export logs. Please try again.',
                                                icon:
                                                    Icons.error_outline_rounded,
                                              );
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
                                        label: const Text(
                                          "Export Logs",
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
              child: const Text("OK"),
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
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('OK'),
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
                                'Filter Options',
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
                                'Choose your preferred view',
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
                                      width: isSelected ? 2 : 1,
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
                                              filterOption,
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
                                          activeColor: Colors.white,
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
                            widget.id = selectedId;
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
                        label: const Text(
                          "Apply Filter",
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
        return 'View all visitor entries and exits';
      case 'visitor in':
        return 'Show only checked-in visitors';
      case 'visitor out':
        return 'Show only checked-out visitors';
      case 'cards':
        return 'View visitors with card access';
      default:
        return 'Filter visitor log entries';
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

  /// Enhanced success toast
  void _showEnhancedSuccessToast({
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
                  icon ?? Icons.check_circle_rounded,
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

  /// Enhanced empty state for search results
  Widget _buildEnhancedEmptySearchState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Enhanced icon container
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1200),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xffF44336).withOpacity(0.1),
                        const Color(0xffff5722).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(60),
                    border: Border.all(
                      color: const Color(0xffF44336).withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: const Color(0xffF44336).withOpacity(0.7),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // Enhanced title
          Text(
            'No Visitors Found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff212427),
                  fontSize: 24,
                  letterSpacing: -0.5,
                ),
          ),

          const SizedBox(height: 12),

          // Enhanced description
          Text(
            'We couldn\'t find any visitors matching "$_searchText"',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xff57636C),
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
          ),

          const SizedBox(height: 8),

          // Additional helper text
          Text(
            'Try adjusting your search terms or check for typos',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xff57636C).withOpacity(0.8),
                  fontSize: 14,
                  height: 1.4,
                ),
          ),

          const SizedBox(height: 32),

          // Enhanced search suggestions
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xffF44336).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline_rounded,
                        color: Color(0xffF44336),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Search Tips',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSearchTip('Try searching by visitor name'),
                const SizedBox(height: 8),
                _buildSearchTip('Check phone number or unit number'),
                const SizedBox(height: 8),
                _buildSearchTip('Use fewer keywords for broader results'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Enhanced empty state for no visitors today
  Widget _buildEnhancedEmptyVisitorsState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Enhanced animated icon
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1500),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -10 + (10 * value)),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xffF44336).withOpacity(0.08),
                        const Color(0xffff5722).withOpacity(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(70),
                  ),
                  child: Icon(
                    Icons.groups_outlined,
                    size: 56,
                    color: const Color(0xffF44336).withOpacity(0.6),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // Enhanced title with animation
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Text(
                  'No Visitors Today',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff212427),
                        fontSize: 26,
                        letterSpacing: -0.5,
                      ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Enhanced description
          Text(
            'It\'s quiet today! When visitors check in through the gate, they will appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xff57636C),
                  fontSize: 16,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
          ),

          const SizedBox(height: 32),

          // Enhanced information card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xffF44336).withOpacity(0.05),
                  const Color(0xffff5722).withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xffF44336).withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xffF44336).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xffF44336),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Visitor Management',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track all visitor entries and exits',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildFeatureItem(Icons.login_rounded, 'Check-ins'),
                    const SizedBox(width: 24),
                    _buildFeatureItem(Icons.logout_rounded, 'Check-outs'),
                    const SizedBox(width: 24),
                    _buildFeatureItem(Icons.schedule_rounded, 'Real-time'),
                  ],
                ),
              ],
            ),
          ),
        ],
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
  Widget _buildFeatureItem(IconData icon, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xffF44336).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xffF44336),
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class VisitorLogItem extends StatefulWidget {
  final VisitorLog visitorLog;
  final Function onCheckOut;

  const VisitorLogItem({
    Key? key,
    required this.visitorLog,
    required this.onCheckOut,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
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
                  backgroundImage: widget
                              .visitorLog.visitor!.visitor_image!.isNotEmpty &&
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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
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
                              color: const Color(0xffF44336).withOpacity(0.2),
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
                            "${_capitalizeFirstLetter(widget.visitorLog.visitor_purpose_Category_name?.toString() ?? "N/A")} ${_getUnitText()}",
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
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
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
                  widget.visitorLog.visitor_card_number != null
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
                                widget.visitorLog.visitor_card_number != null
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
                  (widget.visitorLog.visitor_check_out.toString().isEmpty ||
                          widget.visitorLog.visitor_check_out.toString() ==
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
                              barrierDismissible: true,
                              builder: (BuildContext context) {
                                return Dialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 0,
                                  backgroundColor: Colors.transparent,
                                  child: Container(
                                    padding: const EdgeInsets.all(0),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Enhanced Header
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                                0xffFFEBEE), // OneGate's light red
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(20),
                                              topRight: Radius.circular(20),
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                  borderRadius:
                                                      BorderRadius.circular(50),
                                                ),
                                                child: const Icon(
                                                  Icons.logout_rounded,
                                                  color: Color(0xffF44336),
                                                  size: 32,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'Confirm Checkout',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineSmall
                                                    ?.copyWith(
                                                      color: const Color(
                                                          0xff212427),
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 22,
                                                      letterSpacing: 0.2,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Visitor Departure Confirmation',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: const Color(
                                                          0xff57636C),
                                                      fontSize: 14,
                                                      letterSpacing: 0.3,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Enhanced Content
                                        Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                            children: [
                                              // Visitor info card
                                              Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.all(20),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[50],
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: Colors.grey[200]!,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(8),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: const Color(
                                                                    0xffF44336)
                                                                .withOpacity(
                                                                    0.1),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                          ),
                                                          child: const Icon(
                                                            Icons
                                                                .person_outline_rounded,
                                                            color: Color(
                                                                0xffF44336),
                                                            size: 20,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 12),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                widget
                                                                        .visitorLog
                                                                        .visitor
                                                                        ?.name ??
                                                                    'Visitor',
                                                                style: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .titleMedium
                                                                    ?.copyWith(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: const Color(
                                                                          0xff212427),
                                                                      fontSize:
                                                                          16,
                                                                    ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 2),
                                                              Text(
                                                                'Ready for departure',
                                                                style: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.copyWith(
                                                                      color: const Color(
                                                                          0xff57636C),
                                                                      fontSize:
                                                                          13,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              const SizedBox(height: 20),

                                              // Warning message
                                              Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber[50],
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.amber[200]!,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .info_outline_rounded,
                                                      color: Colors.amber[700],
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        'This action will permanently record the checkout time and cannot be undone.',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: Colors
                                                                  .amber[800],
                                                              fontSize: 13,
                                                              height: 1.4,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              const SizedBox(height: 28),

                                              // Enhanced Action Buttons
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.white,
                                                        foregroundColor:
                                                            const Color(
                                                                0xff57636C),
                                                        elevation: 0,
                                                        shadowColor:
                                                            Colors.transparent,
                                                        side: BorderSide(
                                                          color:
                                                              Colors.grey[300]!,
                                                          width: 1.5,
                                                        ),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          vertical: 16,
                                                          horizontal: 24,
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        Navigator.of(context)
                                                            .pop();
                                                      },
                                                      child: Text(
                                                        'Cancel',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleSmall
                                                            ?.copyWith(
                                                              color: const Color(
                                                                  0xff57636C),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 15,
                                                              letterSpacing:
                                                                  0.3,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: StatefulBuilder(
                                                      builder:
                                                          (context, setState) {
                                                        bool isCheckingOut =
                                                            false;
                                                        return ElevatedButton(
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                            backgroundColor:
                                                                const Color(
                                                                    0xffF44336),
                                                            foregroundColor:
                                                                Colors.white,
                                                            elevation: 0,
                                                            shadowColor: Colors
                                                                .transparent,
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                            ),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              vertical: 16,
                                                              horizontal: 24,
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
                                                                              800)); // Simulate async checkout
                                                                      Navigator.of(
                                                                              context)
                                                                          .pop();
                                                                      widget
                                                                          .onCheckOut();
                                                                      ScaffoldMessenger.of(
                                                                              context)
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
                                                                                  Icons.check_circle_outline_rounded,
                                                                                  color: Colors.white,
                                                                                  size: 24,
                                                                                ),
                                                                              ),
                                                                              const SizedBox(width: 16),
                                                                              Expanded(
                                                                                child: Text(
                                                                                  'Visitor checked out successfully',
                                                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                                                        color: Colors.white,
                                                                                        fontWeight: FontWeight.bold,
                                                                                      ),
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                          backgroundColor:
                                                                              const Color(0xff43A047),
                                                                          behavior:
                                                                              SnackBarBehavior.floating,
                                                                          shape:
                                                                              RoundedRectangleBorder(
                                                                            borderRadius:
                                                                                BorderRadius.circular(12),
                                                                          ),
                                                                          margin:
                                                                              EdgeInsets.all(16),
                                                                          duration:
                                                                              const Duration(milliseconds: 3000),
                                                                          elevation:
                                                                              8,
                                                                        ),
                                                                      );
                                                                    },
                                                          child: isCheckingOut
                                                              ? const SizedBox(
                                                                  width: 22,
                                                                  height: 22,
                                                                  child:
                                                                      CircularProgressIndicator(
                                                                    valueColor: AlwaysStoppedAnimation<
                                                                            Color>(
                                                                        Colors
                                                                            .white),
                                                                    strokeWidth:
                                                                        2.5,
                                                                  ),
                                                                )
                                                              : Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    const Icon(
                                                                      Icons
                                                                          .logout_rounded,
                                                                      size: 18,
                                                                      color: Colors
                                                                          .white,
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            8),
                                                                    Text(
                                                                      'Checkout',
                                                                      style: Theme.of(
                                                                              context)
                                                                          .textTheme
                                                                          .titleSmall
                                                                          ?.copyWith(
                                                                            color:
                                                                                Colors.white,
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                            fontSize:
                                                                                15,
                                                                            letterSpacing:
                                                                                0.3,
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
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          child: Text(
                            'Checkout',
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
                          message: widget.visitorLog.visitor_check_out != null
                              ? DateFormat('dd-MM-yyyy hh:mm a')
                                  .format(widget.visitorLog.visitor_check_out!)
                              : "No check-out time",
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffF44336).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xffF44336).withOpacity(0.3),
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
                                  widget.visitorLog.visitor_check_out != null
                                      ? Utils.convertDateTimeFormat(
                                          widget.visitorLog.visitor_check_out!)
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
