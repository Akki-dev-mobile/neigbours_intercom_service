import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/request_permission/ui/request_permission_view.dart';
import 'package:flutter_onegate/timeprovider.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    await loadApprovalTime(context); // Get latest approval time
    final endTime = DateTime.now().add(approvalDuration);
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
        // Correct way to restart the timer
        await startTimer(visitorLogId, context);
      }
    } catch (e) {
      debugPrint("❌ Error in loadTimerState: $e");

      // Fallback: Start timer if any error occurs
      await startTimer(visitorLogId, context);
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
                    child: CircularProgressIndicator(
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
      return Text(
        'Time ELapsed',
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.bold,
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

class VisitorInfo {
  final int visitorId;
  final String visitorName;
  final String visitorMobile;
  final String visitorImage;
  final String allowStatus;
  final int? visitorLogId;
  final int companyId;
  final String inGate;
  final String logCreatedAt;
  final MemberInfo memberInfo;
  final String? visitorComingFrom;
  final int? visitorPurposeCategoryId;
  final String? purposeCategoryName; // Added field
  final String? purposeSubCategoryName;
  final UnitDetails unitDetails;

  VisitorInfo({
    required this.visitorId,
    required this.visitorName,
    required this.visitorMobile,
    required this.visitorImage,
    required this.allowStatus,
    this.visitorLogId,
    required this.unitDetails,
    required this.companyId,
    required this.inGate,
    required this.logCreatedAt,
    required this.memberInfo,
    this.visitorComingFrom,
    this.visitorPurposeCategoryId,
    this.purposeCategoryName,
    this.purposeSubCategoryName,
  });

  factory VisitorInfo.fromJson(Map<String, dynamic> json) {
    List<UnitDetails> parsedUnitDetails = [];

    try {
      final unitDetailsString = json['unit_details'];

      if (unitDetailsString is String) {
        final List<dynamic> decodedUnitDetails = jsonDecode(unitDetailsString);

        parsedUnitDetails = decodedUnitDetails.map<UnitDetails>((unitJson) {
          final unit = UnitDetails(
            unitId: _parseToInt(unitJson['unit_id']),
            building_unit: unitJson["building_unit"]?.toString() ?? '',
          );

          log("🔍 Parsed building_unit: ${unit.building_unit}");

          return unit;
        }).toList();
      } else if (unitDetailsString is List) {
        parsedUnitDetails = unitDetailsString.map<UnitDetails>((unitJson) {
          final unit = UnitDetails(
            unitId: _parseToInt(unitJson['unit_id']),
            building_unit: unitJson["building_unit"]?.toString() ?? '',
          );

          log("🔍 Parsed building_unit: ${unit.building_unit}");

          return unit;
        }).toList();
      }
    } catch (e) {
      log("❌ Error decoding unit details: $e");
    }

    // 🔍 Print final assigned building_unit
    log("✅ Final assigned building_unit: ${parsedUnitDetails.isNotEmpty ? parsedUnitDetails.first.building_unit : 'N/A'}");

    return VisitorInfo(
      visitorId: _parseToInt(json['visitor_id']),
      visitorName: json['visitor_name']?.toString() ?? '',
      visitorMobile: json['visitor_mobile']?.toString() ?? '',
      visitorImage: json['visitor_image']?.toString() ?? '',
      allowStatus: json['allow_status']?.toString() ?? '',
      visitorLogId: _parseToInt(json['visitor_log_id']),
      companyId: _parseToInt(json['company_id']),
      inGate: json['in_gate']?.toString() ?? '',
      logCreatedAt: json['log_created_at']?.toString() ?? '',
      unitDetails: parsedUnitDetails.isNotEmpty
          ? parsedUnitDetails.first
          : UnitDetails(unitId: 0, building_unit: ''),
      memberInfo: MemberInfo(
        name: json['member_name']?.toString() ?? '',
        mobileNumber: json['memb_mobile_number']?.toString(),
        email: json['memb_email']?.toString(),
        memberId: _parseToInt(json['member_id']),
        unitId: _parseToInt(json['unit_id']),
        building_unit: json["building_unit"]?.toString(),
      ),
      visitorComingFrom: json['visitor_coming_from']?.toString(),
      visitorPurposeCategoryId:
          _parseToInt(json['visitor_purpose_category_id']),
      purposeCategoryName: json['purpose_category_name']?.toString(),
      purposeSubCategoryName: json['purpose_sub_category_name']?.toString(),
    );
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  @override
  String toString() {
    return '''
    VisitorInfo(
      visitorId: $visitorId, 
      visitorName: $visitorName, 
      visitorMobile: $visitorMobile, 
      allowStatus: $allowStatus, 
      visitorLogId: $visitorLogId, 
      companyId: $companyId, 
      inGate: $inGate, 
      logCreatedAt: $logCreatedAt, 
      visitorComingFrom: $visitorComingFrom, 
      visitorPurposeCategoryId: $visitorPurposeCategoryId,
      purposeCategoryName: $purposeCategoryName,
      purposeSubCategoryName: $purposeSubCategoryName,
      memberInfo: $memberInfo
      unit_details:$unitDetails
    )
    ''';
  }
}

class MemberInfo {
  final String name;
  final String? mobileNumber;
  final String? email;
  final int? unitId;
  final int? memberId;
  final String? building_unit;

  MemberInfo(
      {required this.name,
      this.mobileNumber,
      this.email,
      this.unitId,
      this.memberId,
      this.building_unit});
}

class UnitDetails {
  final int? unitId;

  final String? building_unit;

  UnitDetails({this.unitId, this.building_unit});
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
  DateTime _lastRefreshTime = DateTime.now();
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _futureApprovals = widget.remoteDataSource.fetchApprovals();
    _lastRefreshTime = DateTime.now();
    _updateCurrentTime();
    _startAutoRefresh();
    _startTimeUpdate();
  }

  void _startTimeUpdate() {
    // Update time every second
    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateCurrentTime();
      }
    });
  }

  void _updateCurrentTime() {
    setState(() {
      _currentTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    });
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
            _lastRefreshTime = DateTime.now();
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

  Widget _buildSearchField() {
    return CustomForm.textField(
      "Search",
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Missed Approvals',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            if (_isRefreshing)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              ),
          ],
        ),
        actions: [
          // Current time display
          // Center(
          //   child: Padding(
          //     padding: const EdgeInsets.symmetric(horizontal: 16.0),
          //     child: Text(
          //       _currentTime,
          //       style: const TextStyle(
          //         fontSize: 14,
          //         fontWeight: FontWeight.w500,
          //       ),
          //     ),
          //   ),
          // ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
            tooltip: 'Refresh',
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Last refresh time indicator
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Text(
                //   'Last updated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_lastRefreshTime)}',
                //   style: TextStyle(
                //     color: Colors.grey[600],
                //     fontSize: 12,
                //   ),
                // ),
                if (_isRefreshing)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  ),
              ],
            ),
          ),
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
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.black,
                      ),
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
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No missed approvals',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pull to refresh',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ApprovalsList(
                    approvals: snapshot.data!,
                    searchQuery: _searchQuery,
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

  const ApprovalsList({
    Key? key,
    required this.approvals,
    required this.searchQuery,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Apply search filter
    final filteredApprovals = approvals.where((visitor) {
      final query = searchQuery.toLowerCase();
      return visitor.visitorName.toLowerCase().contains(query) ||
          visitor.memberInfo.name.toLowerCase().contains(query) ||
          visitor.inGate.toLowerCase().contains(query);
    }).toList();

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
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: approvalsForDate.length,
              itemBuilder: (context, innerIndex) {
                return MissedApprovalCard(
                  visitorInfo: approvalsForDate[innerIndex],
                  key: ValueKey(approvalsForDate[innerIndex].visitorLogId),
                );
              },
            ),
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
  final TimerService _timerService = TimerService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeTimer();
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

      await timerService.startTimer(visitorLogId, context);
      setState(() {});
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
      await _sendFcmNotification();

      await timerService.startTimer(visitorLogId, context);
      timerService.markRetryAttempt(visitorLogId); // ✅ Mark Retry as Attempted

      setState(() {});
    } catch (e) {
      _showSnackBar('Failed to resend notification', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendFcmNotification() async {
    String formattedInTime =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('visitorId');
      final String? visitorLogId = prefs.getString("visitor_log");

      final requestData = {
        'company_id': widget.visitorInfo.companyId.toString(),
        'name': widget.visitorInfo.visitorName,
        'mobile': widget.visitorInfo.visitorMobile,
        'purpose': "Guest",
        'in_time': formattedInTime,
        'user_id': "77525",

        // (int.tryParse(userId ?? "0") == null ||
        //         int.tryParse(userId ?? "0") == 0)
        //     ? "234567"
        //     : int.parse(userId!).toString(),
        'visitor_count':
            "1", // Assuming visitor_count is not visitorInfo.toString()
        'member_mobile_number': "918452060059",
        'visitor_id': widget.visitorInfo.visitorId.toString(),
        'purpose_category': widget.visitorInfo.visitorPurposeCategoryId == 3
            ? "delivery"
            : widget.visitorInfo.visitorPurposeCategoryId.toString(),
        'visitor_log_id': visitorLogId ?? "",
        'coming_from': widget.visitorInfo.visitorComingFrom ?? "Bandra",
        'member_id': widget.visitorInfo.memberInfo.memberId.toString(),
      };

      log("📡 Sending FCM Request: ${jsonEncode(requestData)}");

      final response = await Dio().post(
        '{https://stggateapi.cubeone.in/api}/visitor/sendFcmNotification',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: requestData,
      );

      if (response.statusCode == 200) {
        log("✅ FCM Notification Sent Successfully: ${response.data}");
        _showSnackBar("Notification sent successfully!");
      } else {
        log("❌ FCM Notification Failed: ${response.statusMessage}");
        _showSnackBar("Error sending notification.", isError: true);
      }
    } catch (e) {
      log("❌ Error in _sendFcmNotification: $e");
      _showSnackBar("Failed to send notification.", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        VisitorInfoSection(
          visitorInfo: widget.visitorInfo,
          onRetry: () {
            _handleRetry(context);
          },
          isLoading: _isLoading,
        ),
      ],
    );
  }
}

class VisitorInfoSection extends StatelessWidget {
  final VoidCallback onRetry;
  final bool isLoading;

  final VisitorInfo visitorInfo;

  const VisitorInfoSection(
      {Key? key,
      required this.visitorInfo,
      required this.onRetry,
      required this.isLoading})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 2,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ListTile(
              onTap: () {},
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 2,
              ),
              leading: CircleAvatar(
                backgroundImage: visitorInfo.visitorImage.isNotEmpty
                    ? NetworkImage(visitorInfo.visitorImage)
                    : const NetworkImage(
                        'https://images.unsplash.com/photo-1731778572747-315c9089bc69?q=80&w=2940&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D'),
                child: visitorInfo.visitorImage.isEmpty
                    ? Text(
                        visitorInfo.visitorImage.isNotEmpty
                            ? visitorInfo.visitorName[0]
                            : 'G',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    : null,
              ),
              title: Text(
                visitorInfo.visitorName,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: Text(
                "${visitorInfo.purposeSubCategoryName ?? visitorInfo.purposeCategoryName ?? ""} - ${visitorInfo.unitDetails.building_unit}",
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Divider(
              indent: 16,
              endIndent: 16,
              color: Colors.grey[200],
            ),
            TimerActionSection(
              visitorInfo: visitorInfo,
              visitorLogId: visitorInfo.visitorLogId ?? 0,
              onRetry: onRetry,
              isLoading: isLoading,
            ),
          ],
        ),
      ),
    );
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
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        child: visitorInfo.visitorImage.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: visitorInfo.visitorImage,
                imageBuilder: (context, imageProvider) => CircleAvatar(
                  radius: 28,
                  backgroundImage: imageProvider,
                ),
                placeholder: (context, url) => const CircularProgressIndicator(
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
class TimerActionSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return TimerBuilder.periodic(
      const Duration(seconds: 1),
      builder: (context) {
        final timerState = TimerService().getTimerState(visitorLogId);
        if (timerState == null) return const SizedBox.shrink();
        final timerService = context.watch<TimerService>();
        final hasRetried = timerService.hasRetried(visitorLogId);
        final now = DateTime.now();
        final remaining = timerState.endTime.difference(now);
        final isEnabled =
            remaining.isNegative || timerState.isRetryEnabled && !hasRetried;

        final allowStatus = visitorInfo.allowStatus.toLowerCase();

        // ✅ Define different states
        final isVisitorAllowed =
            allowStatus == "allowed" || allowStatus == "always_allowed";

        final isVisitorDeclined =
            allowStatus == "declined" || allowStatus == "denied";

        final isVisitorPending =
            allowStatus == "pending" || allowStatus == "request";

        final isVisitorWaiting = allowStatus == "waiting";

        final isVisitorLeave = allowStatus == "leave";

        final isVisitorNotReachable =
            allowStatus == "invalid" || allowStatus == "not_reachable";

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Column(
                children: [
                  // ✅ Case: Visitor Allowed
                  if (isVisitorAllowed)
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 15),
                        const SizedBox(width: 8),
                        Text(
                          "Visitor has been allowed.",
                          style:
                              Theme.of(context).textTheme.labelMedium!.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                        ),
                      ],
                    )

                  // ✅ Case: Visitor Declined
                  else if (isVisitorDeclined)
                    Row(
                      children: [
                        const Icon(Icons.cancel, color: Colors.red, size: 15),
                        const SizedBox(width: 8),
                        Text(
                          "Visitor has been declined.",
                          style:
                              Theme.of(context).textTheme.labelMedium!.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                        ),
                      ],
                    )

                  // ✅ Case: Visitor is Pending Approval
                  else if (isVisitorPending)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.hourglass_empty,
                                    color: Colors.orange, size: 15),
                                const SizedBox(width: 8),
                                Text(
                                  "Approval is pending...",
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium!
                                      .copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade700,
                                      ),
                                ),
                              ],
                            ),
                            isEnabled
                                ? SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width * 0.2,
                                    child: RetryButton(
                                      onRetry: onRetry,
                                      isEnabled: isEnabled && !isLoading,
                                      isLoading: isLoading,
                                    ),
                                  )
                                : TimerDisplay(
                                    remaining: remaining,
                                    isEnabled: isEnabled,
                                  ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Adds spacing
                        // Row(
                        //   mainAxisAlignment: MainAxisAlignment.end,
                        //   children: [
                        //     isEnabled
                        //         ? SizedBox(
                        //             width:
                        //                 MediaQuery.of(context).size.width * 0.3,
                        //             child: RetryButton(
                        //               onRetry: onRetry,
                        //               isEnabled: isEnabled && !isLoading,
                        //               isLoading: isLoading,
                        //             ),
                        //           )
                        //         : TimerDisplay(
                        //             remaining: remaining,
                        //             isEnabled: isEnabled,
                        //           ),
                        //   ],
                        // ),
                      ],
                    )

                  // ✅ Case: Visitor is Waiting
                  else if (isVisitorWaiting)
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            color: Colors.blue, size: 15),
                        const SizedBox(width: 8),
                        Text(
                          "Visitor is waiting at the gate.",
                          style:
                              Theme.of(context).textTheme.bodySmall!.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                        ),
                      ],
                    )

                  // ✅ Case: Visitor has Left
                  else if (isVisitorLeave)
                    Row(
                      children: [
                        const Icon(Icons.directions_walk,
                            color: Colors.brown, size: 15),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Delivery person has left the parcel",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.brown.shade700,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    )

                  // ✅ Case: Visitor is Not Reachable
                  else if (isVisitorNotReachable)
                    Row(
                      children: [
                        const Icon(Icons.signal_wifi_off,
                            color: Colors.grey, size: 15),
                        const SizedBox(width: 8),
                        Text(
                          "Visitor is not reachable.",
                          style:
                              Theme.of(context).textTheme.bodySmall!.copyWith(
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
                          child: RetryButton(
                            onRetry: onRetry,
                            isEnabled: isEnabled && !isLoading,
                            isLoading: isLoading,
                          ),
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
            ],
          ),
        );
      },
    );
  }
}
