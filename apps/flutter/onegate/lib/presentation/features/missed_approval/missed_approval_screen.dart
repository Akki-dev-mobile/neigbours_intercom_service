import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/common/environment.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/data/visitor_info.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/request_permission/ui/request_permission_view.dart';
import 'package:flutter_onegate/presentation/features/missed_approval/widget/time_provider.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/ui/visitor_detail_@.dart';
import 'package:flutter_onegate/services/app_calling/app_to_app.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:common_widgets/dashboard_loader.dart';
import 'package:flutter/services.dart';

// Timer Service
class TimerState {
  final DateTime endTime;
  final bool isRetryEnabled;
  final bool hasRetried; // ✅ Track retry status

  TimerState({
    required this.endTime,
    required this.isRetryEnabled,
    this.hasRetried = false, // Default: false
  });

  TimerState copyWith({
    DateTime? endTime,
    bool? isRetryEnabled,
    bool? hasRetried,
  }) {
    return TimerState(
      endTime: endTime ?? this.endTime,
      isRetryEnabled: isRetryEnabled ?? this.isRetryEnabled,
      hasRetried: hasRetried ?? this.hasRetried,
    );
  }
}

class TimerService extends ChangeNotifier {
  static final TimerService _instance = TimerService._internal();

  factory TimerService() => _instance;

  TimerService._internal();

  void markRetryAttempt(int visitorLogId) {
    final state = _timers[visitorLogId];
    if (state != null) {
      _timers[visitorLogId] = state.copyWith(hasRetried: true);
      notifyListeners();
    }
  }

  bool hasRetried(int visitorLogId) {
    return _timers[visitorLogId]?.hasRetried ?? false;
  }

  final Map<int, TimerState> _timers = {};
  int _approvalTime = 120; // Default approval time

  Duration get approvalDuration => Duration(seconds: _approvalTime);

  Future<void> loadApprovalTime(BuildContext context) async {
    _approvalTime = context.read<VisitorApprovalTimeProvider>().approvalTime;
    notifyListeners();
  }

  Future<void> startTimer(int visitorLogId, BuildContext context) async {
    // Store approval time in a local variable to avoid BuildContext issues
    int approvalTimeValue = _approvalTime;

    try {
      // Try to get the latest approval time if context is valid
      if (context.mounted) {
        approvalTimeValue =
            context.read<VisitorApprovalTimeProvider>().approvalTime;
      }
    } catch (e) {
      debugPrint("❌ Error loading approval time: $e");
      // Continue with the current _approvalTime value
    }

    // Use the approval time value
    final endTime = DateTime.now().add(Duration(seconds: approvalTimeValue));
    _timers[visitorLogId] = TimerState(
      endTime: endTime,
      isRetryEnabled: false,
    );
    await saveTimerState(visitorLogId, endTime);
  }

  Future<void> saveTimerState(int visitorLogId, DateTime endTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('timer_$visitorLogId', endTime.toIso8601String());
  }

  Future<void> loadTimerState(int visitorLogId, BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String timerKey = 'timer_$visitorLogId';
      final dynamic savedValue = prefs.get(timerKey);
      DateTime? endTime;

      if (savedValue is int) {
        endTime = DateTime.fromMillisecondsSinceEpoch(savedValue);
      } else if (savedValue is String) {
        try {
          endTime = DateTime.parse(savedValue);
        } catch (e) {
          debugPrint("❌ Error parsing DateTime string: $savedValue, Error: $e");
        }
      }

      if (endTime != null) {
        _timers[visitorLogId] = TimerState(
          endTime: endTime,
          isRetryEnabled: endTime.isBefore(DateTime.now()),
        );
      } else {
        // Start timer with the provided context, but check if it's still valid
        if (context.mounted) {
          await startTimer(visitorLogId, context);
        } else {
          // If context is not valid, use default approval time
          final endTime = DateTime.now().add(Duration(seconds: _approvalTime));
          _timers[visitorLogId] = TimerState(
            endTime: endTime,
            isRetryEnabled: false,
          );
          await saveTimerState(visitorLogId, endTime);
        }
      }
    } catch (e) {
      debugPrint("❌ Error in loadTimerState: $e");

      // Fallback: Start timer if any error occurs, but check if context is still valid
      if (context.mounted) {
        await startTimer(visitorLogId, context);
      } else {
        // If context is not valid, use default approval time
        final endTime = DateTime.now().add(Duration(seconds: _approvalTime));
        _timers[visitorLogId] = TimerState(
          endTime: endTime,
          isRetryEnabled: false,
        );
        await saveTimerState(visitorLogId, endTime);
      }
    }
  }

  TimerState? getTimerState(int visitorLogId) => _timers[visitorLogId];

  void disposeTimer(int visitorLogId) {
    _timers.remove(visitorLogId);
  }

  void disposeAllTimers() {
    _timers.clear();
  }
}

// Timer Builder Widget
class TimerBuilder extends StatefulWidget {
  final Duration duration;
  final Widget Function(BuildContext context) builder;

  const TimerBuilder.periodic(
    this.duration, {
    Key? key,
    required this.builder,
  }) : super(key: key);

  @override
  State<TimerBuilder> createState() => _TimerBuilderState();
}

class _TimerBuilderState extends State<TimerBuilder> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.duration, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

// Retry Button Widget
class RetryButton extends StatelessWidget {
  final VoidCallback onRetry;
  final bool isEnabled;
  final bool isLoading;

  const RetryButton({
    Key? key,
    required this.onRetry,
    required this.isEnabled,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isEnabled ? onRetry : null,
      // style: ElevatedButton.styleFrom(
      //   padding: const EdgeInsets.symmetric(vertical: 12),
      //   shape: RoundedRectangleBorder(
      //     borderRadius: BorderRadius.circular(8),
      //   ),
      // ),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
            border: Border.all(), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isLoading
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: DashboardLoaderIcon(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : const Icon(
                    Icons.refresh,
                    size: 16,
                    color: Colors.black,
                  ),
            const SizedBox(
              width: 5,
            ),
            Text(
              isLoading ? 'Sending...' : 'Retry',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

// Timer Display Widget
class TimerDisplay extends StatelessWidget {
  final Duration remaining;
  final bool isEnabled;

  const TimerDisplay({
    Key? key,
    required this.remaining,
    required this.isEnabled,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isEnabled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red.withOpacity(0.18),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(
              'Time Elapsed',
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      );
    }

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return Text(
      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      style: TextStyle(
        color: remaining.inSeconds < 30 ? Colors.red : Colors.black54,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

// Main Screen with Search
class MissedApprovalsScreen extends StatefulWidget {
  final RemoteDataSource remoteDataSource;

  const MissedApprovalsScreen({
    Key? key,
    required this.remoteDataSource,
  }) : super(key: key);

  @override
  State<MissedApprovalsScreen> createState() => _MissedApprovalsScreenState();
}

class _MissedApprovalsScreenState extends State<MissedApprovalsScreen> {
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  late Future<List<VisitorInfo>> _futureApprovals;
  String _searchQuery = '';
  Timer? _refreshTimer;
  Timer? _timeUpdateTimer;
  bool _isRefreshing = false;
  String? selectedBuilding = "All Buildings";

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _futureApprovals = widget.remoteDataSource.fetchApprovals();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    // Refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _refreshTimer?.cancel();
    _timeUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (_isRefreshing || !mounted) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await widget.remoteDataSource.fetchApprovals().then((data) {
        if (mounted) {
          setState(() {
            _futureApprovals = Future.value(data);
          });
        }
      });
    } catch (e) {
      log("❌ Error refreshing data: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  /// Enhanced empty state with OneGate new UI design
  Widget _buildEnhancedEmptyState() {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight = screenHeight - keyboardHeight;

    return Container(
      height: availableHeight,
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 24,
        vertical: isTablet ? 60 : 40,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Enhanced animated icon
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1500),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -10 + (10 * value)),
                child: Container(
                  width: isTablet ? 160 : 140,
                  height: isTablet ? 160 : 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xffF44336).withOpacity(0.08),
                        const Color(0xffff5722).withOpacity(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(isTablet ? 80 : 70),
                  ),
                  child: Icon(
                    Icons.approval_outlined,
                    size: isTablet ? 64 : 56,
                    color: const Color(0xffF44336).withOpacity(0.6),
                  ),
                ),
              );
            },
          ),

          SizedBox(height: isTablet ? 40 : 32),

          // Enhanced title with animation
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Text(
                  'No Missed Approvals',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff212427),
                        fontSize: isTablet ? 30 : 26,
                        letterSpacing: -0.5,
                      ),
                ),
              );
            },
          ),

          SizedBox(height: isTablet ? 20 : 16),

          // Enhanced description
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 40 : 20),
            child: Text(
              'No missed approvals found today.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xff57636C),
                    fontSize: isTablet ? 18 : 16,
                    height: 1.6,
                    fontWeight: FontWeight.w400,
                  ),
            ),
          ),
        ],
      ),
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

  Widget _buildSearchField() {
    return Column(
      children: [
        // Search field
        CustomForm.textField(
          "",
          hintText: "Search by Visitor Name",
          titleColor: Theme.of(context).colorScheme.onSurface,
          hintColor: Theme.of(context).colorScheme.onSurface,
          focusNode: _searchFocusNode,
          prefixIcon: const Icon(Ionicons.search_outline),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          textController: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),

        // Building selection dropdown
        // FutureBuilder<List<VisitorInfo>>(
        //   future: _futureApprovals,
        //   builder: (context, snapshot) {
        //     // Extract building names from visitor logs using the helper method
        //     Set<String> buildingNames = {"All Buildings"};
        //
        //     if (snapshot.hasData) {
        //       buildingNames = BuildingDropdown.extractBuildingNames(
        //         snapshot.data!,
        //         getUnitName: (VisitorInfo visitor) {
        //           if (visitor.unitDetails.building_unit != null &&
        //               visitor.unitDetails.building_unit!.isNotEmpty) {
        //             return visitor.unitDetails.building_unit!;
        //           }
        //           return "";
        //         },
        //       );
        //     }
        //
        //     List<String> sortedBuildingNames = buildingNames.toList();
        //
        //     return BuildingDropdown(
        //       selectedBuilding: selectedBuilding,
        //       onBuildingSelected: (String? value) {
        //         setState(() {
        //           selectedBuilding = value;
        //         });
        //       },
        //       buildingNames: sortedBuildingNames,
        //     );
        //   },
        // ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xffF44336), Color(0xffD32F2F)],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xffF44336).withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.phone_missed_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Missed Approvals',
              style: TextStyle(
                color: Color(0xff212427),
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isRefreshing
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        _refreshData();
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.refresh,
                    color: Color(0xff57636C),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildSearchField(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: FutureBuilder<List<VisitorInfo>>(
                future: _futureApprovals,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !_isRefreshing) {
                    return const DashboardLoader(
                      title: 'Loading Missed Approvals',
                      subtitle:
                          'Please wait while we fetch pending approvals...',
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _refreshData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEnhancedEmptyState();
                  }

                  return ApprovalsList(
                    approvals: snapshot.data!,
                    searchQuery: _searchQuery,
                    selectedBuilding: selectedBuilding,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Modified ApprovalsList with Search
class ApprovalsList extends StatelessWidget {
  final List<VisitorInfo> approvals;
  final String searchQuery;
  final String? selectedBuilding;

  const ApprovalsList({
    Key? key,
    required this.approvals,
    required this.searchQuery,
    this.selectedBuilding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Apply search filter
    List<VisitorInfo> filteredApprovals = approvals.where((visitor) {
      final query = searchQuery.toLowerCase();
      return visitor.visitorName.toLowerCase().contains(query) ||
          visitor.memberInfo.name.toLowerCase().contains(query) ||
          visitor.inGate.toLowerCase().contains(query);
    }).toList();

    // Filter by selected building if not "All Buildings"
    if (selectedBuilding != null && selectedBuilding != "All Buildings") {
      filteredApprovals = filteredApprovals.where((visitor) {
        if (visitor.unitDetails.building_unit != null &&
            visitor.unitDetails.building_unit!.isNotEmpty) {
          String unitId = visitor.unitDetails.building_unit!;
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

    // Group approvals by date
    final Map<String, List<VisitorInfo>> groupedByDate = {};

    for (var approval in filteredApprovals) {
      final logDate = DateFormat('yyyy-MM-dd')
          .format(DateTime.parse(approval.logCreatedAt));

      if (!groupedByDate.containsKey(logDate)) {
        groupedByDate[logDate] = [];
      }
      groupedByDate[logDate]!.add(approval);
    }

    // Convert map to sorted list of entries by date (descending order)
    final groupedList = groupedByDate.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    if (groupedList.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 48,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withAlpha(153), // ~0.6 opacity
          ),
          Text(
            searchQuery.isNotEmpty
                ? "No results found for '$searchQuery'"
                : "No approvals found",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedList.length,
      itemBuilder: (context, index) {
        final dateKey = groupedList[index].key;
        final approvalsForDate = groupedList[index].value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Chip as Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 0.0),
              child: Center(
                child: Chip(
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        25), // Adjust the radius as needed
                    side: BorderSide.none, // No border
                  ),
                  label: Text(
                    DateFormat('dd MMM, yyyy').format(
                      DateTime.parse(dateKey),
                    ),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),

            // Approvals List for this Date
            Builder(builder: (context) {
              // Sort approvals by building name within each date group
              approvalsForDate.sort((a, b) {
                String buildingA = "";
                String buildingB = "";

                if (a.unitDetails.building_unit != null &&
                    a.unitDetails.building_unit!.isNotEmpty) {
                  String unitId = a.unitDetails.building_unit!;
                  if (unitId.contains("-")) {
                    buildingA = unitId.split("-")[0].trim();
                  } else {
                    buildingA = unitId;
                  }
                }

                if (b.unitDetails.building_unit != null &&
                    b.unitDetails.building_unit!.isNotEmpty) {
                  String unitId = b.unitDetails.building_unit!;
                  if (unitId.contains("-")) {
                    buildingB = unitId.split("-")[0].trim();
                  } else {
                    buildingB = unitId;
                  }
                }

                return buildingA.compareTo(buildingB);
              });

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: approvalsForDate.length,
                itemBuilder: (context, innerIndex) {
                  return MissedApprovalCard(
                    visitorInfo: approvalsForDate[innerIndex],
                    key: ValueKey(approvalsForDate[innerIndex].visitorLogId),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }
}

// Card Widget
class MissedApprovalCard extends StatefulWidget {
  final VisitorInfo visitorInfo;

  const MissedApprovalCard({
    Key? key,
    required this.visitorInfo,
  }) : super(key: key);

  @override
  State<MissedApprovalCard> createState() => _MissedApprovalCardState();
}

class _MissedApprovalCardState extends State<MissedApprovalCard> {
  late SocketService _socketService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeTimer();
    _initializeSocketConnection();
  }

  @override
  void dispose() {
    // Clean up socket connection
    _socketService.disconnect();
    super.dispose();
  }

  void _initializeSocketConnection() {
    _socketService = SocketService();
    _socketService.initSocket(
        widget.visitorInfo.companyId.toString(), "onegate");

    // Listen for socket responses
    _socketService.messageStream.listen((message) {
      if (message['event'] == 'fcmResponse') {
        _handleFcmResponse(message['data']);
      }
    });
  }

  Future<void> _initializeTimer() async {
    await context
        .read<TimerService>()
        .loadTimerState(widget.visitorInfo.visitorLogId ?? 0, context);
    if (mounted) setState(() {});
  }

  RequestType _getRequestType(String status) {
    switch (status) {
      case "allowed":
        return RequestType.approved;
      case "denied":
        return RequestType.rejected;
      case "leave":
        return RequestType.leaveAtGate;
      case "invalid":
        return RequestType.notRecheable;
      case "request":
        return RequestType.request;
      case "pending":
        return RequestType.waiting;
      case "always_allowed":
        return RequestType.allowByGatekeeper;
      default:
        return RequestType.rejected;
    }
  }

  Future<void> _handleRetry(BuildContext context) async {
    if (_isLoading) return;

    final timerService = context.read<TimerService>();
    final visitorLogId = widget.visitorInfo.visitorLogId ?? 0;

    if (timerService.hasRetried(visitorLogId)) {
      _showSnackBar('Retry already attempted for this visitor', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    RequestType requestType =
        _getRequestType(widget.visitorInfo.allowStatus.toLowerCase());

    if (requestType == RequestType.approved ||
        requestType == RequestType.allowByGatekeeper) {
      _showSnackBar('Visitor is already allowed', isError: false);

      if (mounted) {
        await timerService.startTimer(visitorLogId, context);
        setState(() {});
      }
      return;
    } else if (requestType == RequestType.rejected) {
      _showSnackBar('Visitor has been denied entry', isError: true);
      return;
    } else if (requestType == RequestType.leaveAtGate) {
      _showSnackBar('Visitor is waiting at the gate', isError: false);
      return;
    } else if (requestType == RequestType.notRecheable) {
      _showSnackBar('Visitor is not reachable', isError: true);
      return;
    }

    try {
      await _sendFcmNotification(); // Fallback to REST API
      // Try to send notification via socket first
      await _sendNotificationViaSocket();

      // Start timer and mark retry attempt
      if (mounted) {
        timerService
            .markRetryAttempt(visitorLogId); // ✅ Mark Retry as Attempted

        // Use a separate function to handle the timer to avoid BuildContext issues
        _startTimerSafely(timerService, visitorLogId);
      }
    } catch (e) {
      log("❌ Error in _handleRetry: $e");
      _showSnackBar('Failed to resend notification', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendNotificationViaSocket() async {
    try {
      // Prepare request data
      final requestData = await _prepareSocketRequestData();

      log("📡 Preparing to send notification via socket");

      // Check if socket is connected
      if (_socketService.socket == null || !_socketService.socket!.connected) {
        log("⚠️ Socket not connected, reconnecting...");
        // Reinitialize socket if not connected
        _socketService.disconnect();
        _socketService = SocketService();

        // Get company ID
        _socketService.initSocket(
            widget.visitorInfo.companyId.toString(), "onegate");

        // Wait for connection to establish
        await Future.delayed(const Duration(seconds: 1));

        if (_socketService.socket == null ||
            !_socketService.socket!.connected) {
          log("❌ Socket connection failed, falling back to REST API");
          await _sendFcmNotification(); // Fallback to REST API
          return;
        }
      }

      // Set up listener for response before sending request
      _socketService.socket!.once("fcmResponse", (responseData) async {
        log("📩 Socket Response Received: $responseData");
        await _handleFcmResponse(responseData);
      });

      // Send notification via socket
      log("📤 Emitting sendFcmNotification event with data: ${jsonEncode(requestData)}");
      _socketService.socket!.emit("sendFcmNotification", requestData);

      // Show a toast to indicate the request is being processed
      _showSnackBar("Sending notification to member...", isError: false);

      // Set a timeout for socket response
      Timer(const Duration(seconds: 5), () {
        // If we haven't received a response after 5 seconds, fall back to REST API
        if (_isLoading) {
          log("⏱️ Socket response timeout, falling back to REST API");
          _sendFcmNotification(); // Fallback to REST API
        }
      });
    } catch (e) {
      log("❌ Error in _sendNotificationViaSocket: $e");
      // Fallback to REST API on error
      await _sendFcmNotification();
    }
  }

  Future<Map<String, dynamic>> _prepareSocketRequestData() async {
    final formattedInTime =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    return {
      'company_id': widget.visitorInfo.companyId.toString(),
      'name': widget.visitorInfo.visitorName,
      'mobile': widget.visitorInfo.visitorMobile,
      'in_time': formattedInTime,
      'user_id': widget.visitorInfo.memberInfo.userId.toString(),
      'visitor_count': "1",
      'purpose':
          widget.visitorInfo.purposeCategoryName?.toLowerCase() ?? "general",
      'member_mobile_number':
          widget.visitorInfo.memberInfo.mobileNumber ?? "917378880544",
      'visitor_id': widget.visitorInfo.visitorId.toString(),
      'purpose_category': widget.visitorInfo.visitorPurposeCategoryId == 3
          ? "delivery"
          : widget.visitorInfo.visitorPurposeCategoryId.toString(),
      'visitor_log_id': widget.visitorInfo.visitorLogId.toString(),
      'coming_from': widget.visitorInfo.visitorComingFrom ?? "Bandra",
      'member_id': widget.visitorInfo.memberInfo.memberId.toString(),
      "self_check_in": "false",
      "company_name": widget.visitorInfo.companyName, // new key
      "file": widget.visitorInfo.visitorImage // new key
    };
  }

  Future<void> _handleFcmResponse(dynamic responseData) async {
    try {
      if (responseData == null) {
        log("❌ FCM Response data is null");
        return;
      }

      log("📩 Full FCM Response: $responseData");

      // Check if the response indicates a successful call initiation via Twilio
      if (responseData["success"] == true &&
          responseData["message"]
                  ?.toString()
                  .contains("call initiated successfully") ==
              true) {
        log("✅ Call initiated successfully via Twilio");

        // Show a toast to inform the user
        _showSnackBar("Call initiated to member successfully", isError: false);
        return;
      }

      // Handle normal FCM response
      final message = responseData["message"];
      log("📩 FCM Response message: $message");

      if (responseData["success"] == true) {
        _showSnackBar("Notification sent successfully", isError: false);
      } else {
        _showSnackBar("Failed to send notification: $message", isError: true);
      }
    } catch (e) {
      log("❌ Error handling FCM response: $e");
      _showSnackBar("Error processing notification response", isError: true);
    }
  }

  Future<void> _sendFcmNotification() async {
    final formattedInTime =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    try {
      final requestData = {
        'company_id': widget.visitorInfo.companyId.toString(),
        'name': widget.visitorInfo.visitorName,
        'mobile': widget.visitorInfo.visitorMobile,
        'in_time': formattedInTime,
        'user_id': widget.visitorInfo.memberInfo.userId.toString(),
        'visitor_count': "1",
        'purpose':
            widget.visitorInfo.purposeCategoryName?.toLowerCase() ?? "general",
        'member_mobile_number':
            widget.visitorInfo.memberInfo.mobileNumber ?? "917378880544",
        'visitor_id': widget.visitorInfo.visitorId.toString(),
        'purpose_category': widget.visitorInfo.visitorPurposeCategoryId == 3
            ? "delivery"
            : widget.visitorInfo.visitorPurposeCategoryId.toString(),
        'visitor_log_id': widget.visitorInfo.visitorLogId.toString(),
        'coming_from': widget.visitorInfo.visitorComingFrom ?? "Bandra",
        'member_id': widget.visitorInfo.memberInfo.memberId.toString(),
        "self_check_in": "false",
        "company_name": widget.visitorInfo.companyName, // new key
        "file": widget.visitorInfo.visitorImage // new key
      };

      log("📨 Sending FCM Notification (800 bytes) with Data: $requestData");
      final headers = await Environment.getHeaders();

      final response = await Dio().post(
        '${ApiUrls.gateBaseUrl}/visitor/sendFcmNotification',
        options: Options(headers: {
          ...headers,
          "Content-Length": "800",
        }),
        data: requestData,
      );

      if (response.statusCode == 200 && response.data != null) {
        log("✅ FCM Notification sent successfully: ${response.data}");
        await _handleFcmResponse(response.data);
      } else {
        log("❌ Failed to send notification. Response: ${response.statusCode} - ${response.data}");
        _showSnackBar("Failed to send notification.", isError: true);
      }
    } catch (e, stackTrace) {
      log("❌ Exception in sending notification: $e");
      log("$stackTrace");
      _showSnackBar("Error occurred while sending notification.",
          isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    myFluttertoast(
      msg: message,
      backgroundColor: isError ? Colors.red : Colors.green,
    );
  }

  Future<void> _startTimerSafely(
      TimerService timerService, int visitorLogId) async {
    // Create a local copy of the context to avoid BuildContext across async gaps
    final BuildContext currentContext = context;

    // Only proceed if the widget is still mounted
    if (!mounted) return;

    // Start the timer
    await timerService.startTimer(visitorLogId, currentContext);

    // Update the UI if still mounted
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VisitorDetailsScreen2(
                visitorLog: widget.visitorInfo,
                isFromMissedApprovalScreen: true,
              ),
            ),
          );
        },
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 4.0), // Reduced for more compact card
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
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
                              .visitorInfo.visitorImage.isNotEmpty
                          ? NetworkImage(widget.visitorInfo.visitorImage)
                          : const NetworkImage(
                              'https://images.unsplash.com/photo-1731778572747-315c9089bc69?q=80&w=2940&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D'),
                      child: widget.visitorInfo.visitorImage.isEmpty
                          ? Text(
                              widget.visitorInfo.visitorName.isNotEmpty
                                  ? widget.visitorInfo.visitorName[0]
                                      .toUpperCase()
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
                    widget.visitorInfo.visitorName,
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
                                _getPurposeIcon(
                                    widget.visitorInfo.purposeSubCategoryName),
                                color: const Color(0xffF44336),
                                size: 15,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Flexible(
                              child: Text(
                                "${_capitalizeFirstLetter(widget.visitorInfo.purposeSubCategoryName ?? "N/A")} - ${widget.visitorInfo.unitDetails.building_unit ?? 'N/A'}",
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
                  height: 16,
                  thickness: 1,
                  color: Colors.grey.shade200,
                ),
                Container(
                  padding: const EdgeInsets.only(
                      bottom: 8.0, top: 6, left: 12, right: 12),
                  child: TimerActionSection(
                    visitorInfo: widget.visitorInfo,
                    visitorLogId: widget.visitorInfo.visitorLogId ?? 0,
                    onRetry: () {
                      _handleRetry(context);
                    },
                    isLoading: _isLoading,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return "";
    return text
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  IconData _getPurposeIcon(String? category) {
    switch (category?.toUpperCase()) {
      case "DELIVERY":
        return Icons.inventory_2_outlined; // Parcel icon for delivery
      case "CABS":
        return Symbols.local_taxi; // Car symbol for cabs
      case "VENDOR":
        return Symbols.settings_suggest;
      case "GUEST":
        return Symbols.person; // Gear icon for vendor
      default:
        return Icons.inventory_2_outlined; // Fallback generic icon
    }
  }
}

// Avatar Widget
class VisitorAvatar extends StatelessWidget {
  final VisitorInfo visitorInfo;

  const VisitorAvatar({
    Key? key,
    required this.visitorInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'visitor_${visitorInfo.visitorId}',
      child: CircleAvatar(
        radius: 30,
        backgroundColor: Theme.of(context).primaryColor.withAlpha(25),
        child: visitorInfo.visitorImage.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: visitorInfo.visitorImage,
                imageBuilder: (context, imageProvider) => CircleAvatar(
                  radius: 28,
                  backgroundImage: imageProvider,
                ),
                placeholder: (context, url) => const DashboardLoaderIcon(
                  color: Colors.black,
                ),
                errorWidget: (context, url, error) => _buildInitial(),
              )
            : _buildInitial(),
      ),
    );
  }

  Widget _buildInitial() {
    return CircleAvatar(
      radius: 28,
      child: Text(
        visitorInfo.visitorName.isNotEmpty
            ? visitorInfo.visitorName[0].toUpperCase()
            : 'G',
        style: const TextStyle(fontSize: 15),
      ),
    );
  }
}

// Timer Action Section
class TimerActionSection extends StatefulWidget {
  final int visitorLogId;
  final VoidCallback onRetry;
  final bool isLoading;
  final VisitorInfo visitorInfo;

  const TimerActionSection({
    Key? key,
    required this.visitorLogId,
    required this.onRetry,
    required this.isLoading,
    required this.visitorInfo,
  }) : super(key: key);

  @override
  TimerActionSectionState createState() => TimerActionSectionState();
}

class TimerActionSectionState extends State<TimerActionSection> {
  bool _isUploading = false;
  bool _isImageUploaded = false;
  RemoteDataSource remoteDataSource = RemoteDataSource();

  @override
  void initState() {
    super.initState();
    _checkIfImageUploaded();
  }

  Future<void> _checkIfImageUploaded() async {
    bool? imageUrl =
        widget.visitorInfo.additionalDetails?["is_parcel_provided"];
    if (imageUrl == true) {
      setState(() {
        _isImageUploaded = true;
      });
    }
  }

  Future<void> _captureAndUploadImage() async {
    setState(() => _isUploading = true);

    try {
      final String? capturedImagePath = await _openCameraAndCapture();

      if (capturedImagePath == null) {
        myFluttertoast(
          msg: "Photo capture cancelled",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        setState(() => _isUploading = false);
        return;
      }

      /// **Upload the Image**
      final String uploadedImageUrl =
          await _uploadImage(File(capturedImagePath));

      /// **Update the backend after successful upload**
      await remoteDataSource.uploadParcelImage(
        visitorLogId: int.parse(widget.visitorInfo.visitorLogId.toString()),
        imageUrl: uploadedImageUrl,
      );

      myFluttertoast(
        msg: "Parcel image uploaded successfully!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      setState(() {
        _isUploading = false;
        _isImageUploaded = true;
      });
    } catch (e) {
      myFluttertoast(
        msg: "Failed to upload parcel image",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      setState(() => _isUploading = false);
    }
  }

  Future<String> _uploadImage(File imageFile) async {
    try {
      setState(() {
        _isUploading = true;
      });

      var data = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: '${widget.visitorInfo.visitorMobile}.jpg',
        ),
        'company_id': '${widget.visitorInfo.companyId}',
        'uuid': widget.visitorInfo.visitorMobile,
        'path': imageFile.path,
      });

      var dio = Dio();
      var response = await dio.post(
        'https://gateapi.cubeone.in/api/visitor/uploadFile',
        data: data,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.statusCode == 200) {
        log('Successfully uploaded: ${json.encode(response.data)}');
        var filePath = response.data['data']?['file_path'];
        if (filePath != null && filePath is String) {
          return filePath;
        }
      }
      throw Exception('Upload failed: ${response.statusMessage}');
    } catch (e) {
      log('Error uploading image: $e');
      rethrow;
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<String?> _openCameraAndCapture() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    return image?.path; // Return the file path or null
  }

  @override
  Widget build(BuildContext context) {
    return TimerBuilder.periodic(
      const Duration(seconds: 1),
      builder: (context) {
        final timerState = TimerService().getTimerState(widget.visitorLogId);
        if (timerState == null) return const SizedBox.shrink();
        final timerService = context.watch<TimerService>();
        final hasRetried = timerService.hasRetried(widget.visitorLogId);
        final now = DateTime.now();
        final remaining = timerState.endTime.difference(now);
        final isEnabled =
            remaining.isNegative || timerState.isRetryEnabled && !hasRetried;

        final allowStatus = widget.visitorInfo.allowStatus.toLowerCase();

        debugPrint("=================================> Status:$allowStatus");

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ✅ Case: Visitor has Left (LEAVE)
              if (allowStatus == "leave")
                _isImageUploaded
                    ? Row(
                        children: [
                          const Icon(Icons.inventory_2,
                              color: Colors.brown, size: 28),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "Delivery person has left the parcel.",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown.shade700,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _isUploading
                                    ? null
                                    : _captureAndUploadImage,
                                icon: _isUploading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: DashboardLoaderIcon(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.camera_alt),
                                label: Text(_isUploading
                                    ? "Uploading..."
                                    : "Capture Image"),
                              ),
                            ],
                          ),
                        ],
                      )

              // ✅ Case: Visitor Allowed
              else if (allowStatus == "allowed")
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      "Visitor has been allowed.",
                      style: Theme.of(context).textTheme.labelMedium!.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade700,
                          ),
                    ),
                  ],
                )

              // ✅ Case: GateKeeper Allowed
              else if (allowStatus == "allowed_by_gatekeeper")
                Row(
                  children: [
                    const Icon(Icons.admin_panel_settings,
                        color: Colors.blue, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      "Visitor is Allowed By Gatekeeper.",
                      style: Theme.of(context).textTheme.labelMedium!.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                )

              // ✅ Case: Visitor Declined
              else if (allowStatus == "declined" || allowStatus == "denied")
                Row(
                  children: [
                    const Icon(Icons.cancel, color: Colors.red, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      "Visitor has been declined.",
                      style: Theme.of(context).textTheme.labelMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                    ),
                  ],
                )

              // ✅ Case: Visitor is Pending Approval
              else if (allowStatus == "pending" || allowStatus == "request")
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.18),
                              width: 1,
                            ),
                          ),
                          child: const Icon(Icons.hourglass_empty,
                              color: Colors.orange, size: 28),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Approval is pending...",
                          style:
                              Theme.of(context).textTheme.labelMedium!.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                        ),
                      ],
                    ),
                    isEnabled
                        ? Container()
                        : TimerDisplay(
                            remaining: remaining,
                            isEnabled: isEnabled,
                          ),
                  ],
                )

              // ✅ Case: Visitor is Not Reachable
              else if (allowStatus == "invalid" ||
                  allowStatus == "not_reachable")
                Row(
                  children: [
                    const Icon(Icons.signal_wifi_off,
                        color: Colors.grey, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      "Visitor is not reachable.",
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                    ),
                  ],
                )

              // ✅ Default Case: Retry Action
              else
                Row(
                  children: [
                    Expanded(
                      child:
                          //  RetryButton(
                          //   onRetry: widget.onRetry,
                          //   isEnabled: isEnabled && !widget.isLoading,
                          //   isLoading: widget.isLoading,
                          // ),
                          Container(),
                    ),
                    const SizedBox(width: 16),
                    TimerDisplay(
                      remaining: remaining,
                      isEnabled: isEnabled,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
