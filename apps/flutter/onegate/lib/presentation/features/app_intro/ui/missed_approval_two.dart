import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
import 'package:flutter_onegate/presentation/features/request_gate_access/ui/request_gate_access_view.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/data/visitor_info.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/request_permission/ui/request_permission_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/ui/visitor_detail_@.dart';
import 'package:flutter_onegate/services/app_calling/app_to_app.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_symbols_icons/symbols.dart';
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

  final Map<int, TimerState> _timers = {};
  final int _approvalTime = 60; // Static 60 seconds timing ✅

  Duration get approvalDuration => Duration(seconds: _approvalTime);

  Future<void> startTimer(int visitorLogId, BuildContext context) async {
    // No need to load from provider
    final endTime = DateTime.now().add(approvalDuration);
    _timers[visitorLogId] = TimerState(
      endTime: endTime,
      isRetryEnabled: false,
    );
    await saveTimerState(visitorLogId, endTime);
    notifyListeners(); // Notify listeners of the change
  }

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

  Future<void> saveTimerState(int visitorLogId, DateTime endTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('timer_$visitorLogId', endTime.toIso8601String());
  }

  Future<void> loadTimerState(int visitorLogId, BuildContext context) async {
    try {
      log("⏱️ Loading timer state for visitor $visitorLogId");
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
        log("⏱️ Timer state loaded: ${_timers[visitorLogId]?.endTime}");
      } else {
        // Check if context is still valid before using it
        if (context.mounted) {
          // Correct way to restart the timer
          await startTimer(visitorLogId, context);
        } else {
          // If context is not valid, use default timer
          final endTime = DateTime.now().add(approvalDuration);
          _timers[visitorLogId] = TimerState(
            endTime: endTime,
            isRetryEnabled: false,
          );
          await saveTimerState(visitorLogId, endTime);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error in loadTimerState: $e");

      // Check if context is still valid before using it
      if (context.mounted) {
        // Fallback: Start timer if any error occurs
        await startTimer(visitorLogId, context);
      } else {
        // If context is not valid, use default timer
        final endTime = DateTime.now().add(approvalDuration);
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
    notifyListeners();
  }

  void disposeAllTimers() {
    _timers.clear();
    notifyListeners();
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

// Main Screen with Search
class MissedApprovalsScreen2 extends StatefulWidget {
  final RemoteDataSource remoteDataSource;
  final String towerName; // ✅ Add this

  const MissedApprovalsScreen2({
    Key? key,
    required this.remoteDataSource,
    required this.towerName, // ✅ Required in constructor
  }) : super(key: key);

  @override
  State<MissedApprovalsScreen2> createState() => _MissedApprovalsScreen2State();
}

class _MissedApprovalsScreen2State extends State<MissedApprovalsScreen2> {
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  late Future<List<VisitorInfo>> _futureApprovals;
  String _searchQuery = '';
  Timer? _refreshTimer;
  Timer? _timeUpdateTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _futureApprovals =
        widget.remoteDataSource.fetchApprovals(isSecondary: true);
    _startAutoRefresh();
    log("Tower name: ${widget.towerName}");
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
      await widget.remoteDataSource
          .fetchApprovals(isSecondary: true)
          .then((data) {
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
    final bool isTablet = MediaQuery.of(context).size.width > 600;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              Text(
                widget.towerName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              // Text(
              //   widget.towerName,
              //   style: Theme.of(context).textTheme.labelSmall?.copyWith(
              //         color: Colors.black,
              //       ),
              // ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    final isTablet = MediaQuery.of(context).size.width > 600;

                    return Dialog(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      child: Container(
                        width: isTablet ? 400 : double.infinity,
                        margin:
                            EdgeInsets.symmetric(horizontal: isTablet ? 0 : 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              spreadRadius: 2,
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(isTablet ? 32 : 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Enhanced header with gradient background
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isTablet ? 24 : 20,
                                  vertical: isTablet ? 20 : 16,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xffF44336).withOpacity(0.08),
                                      const Color(0xffff5722).withOpacity(0.03),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding:
                                          EdgeInsets.all(isTablet ? 16 : 14),
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
                                            color: const Color(0xffF44336)
                                                .withOpacity(0.3),
                                            spreadRadius: 1,
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.logout_rounded,
                                        color: Colors.white,
                                        size: isTablet ? 32 : 28,
                                      ),
                                    ),
                                    SizedBox(width: isTablet ? 20 : 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Confirm Logout',
                                            style: TextStyle(
                                              fontSize: isTablet ? 24 : 20,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xff212427),
                                            ),
                                          ),
                                          SizedBox(height: isTablet ? 6 : 4),
                                          Text(
                                            'Security confirmation required',
                                            style: TextStyle(
                                              fontSize: isTablet ? 14 : 13,
                                              color: const Color(0xff57636C),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: isTablet ? 28 : 24),
                              // Enhanced content section
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(isTablet ? 20 : 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Are you sure you want to logout?',
                                      style: TextStyle(
                                        fontSize: isTablet ? 18 : 16,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xff212427),
                                        height: 1.4,
                                      ),
                                    ),
                                    SizedBox(height: isTablet ? 12 : 10),
                                    Row(
                                      children: [
                                        Container(
                                          padding:
                                              EdgeInsets.all(isTablet ? 8 : 6),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.orange.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.info_outline_rounded,
                                            color: Colors.orange.shade600,
                                            size: isTablet ? 18 : 16,
                                          ),
                                        ),
                                        SizedBox(width: isTablet ? 12 : 10),
                                        Expanded(
                                          child: Text(
                                            'You will need to sign in again to access your account.',
                                            style: TextStyle(
                                              fontSize: isTablet ? 15 : 14,
                                              color: const Color(0xff57636C),
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: isTablet ? 32 : 28),
                              // Enhanced action buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: isTablet ? 56 : 52,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        style: TextButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color: const Color(0xff212427),
                                            fontWeight: FontWeight.w600,
                                            fontSize: isTablet ? 16 : 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: isTablet ? 16 : 12),
                                  Expanded(
                                    child: Container(
                                      height: isTablet ? 56 : 52,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Color(0xffF44336),
                                            Color(0xffD32F2F),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xffF44336)
                                                .withOpacity(0.4),
                                            spreadRadius: 1,
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: TextButton(
                                        onPressed: () async {
                                          logout(context);
                                        },
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: Text(
                                          'Logout',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: isTablet ? 16 : 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
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
                      return const LoaderView(
                        title: "Loading Missed Approvals",
                        subtitle: "Please wait while we fetch the data",
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
                      towerName: widget.towerName,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Modified ApprovalsList with Search and Tower Filter
class ApprovalsList extends StatelessWidget {
  final List<VisitorInfo> approvals;
  final String searchQuery;
  final String towerName;

  const ApprovalsList({
    Key? key,
    required this.approvals,
    required this.searchQuery,
    required this.towerName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Apply search and tower filter
    List<VisitorInfo> filteredApprovals = approvals.where((visitor) {
      final query = searchQuery.toLowerCase();
      final matchesSearch = visitor.visitorName.toLowerCase().contains(query) ||
          visitor.memberInfo.name.toLowerCase().contains(query) ||
          visitor.inGate.toLowerCase().contains(query);

      // Match tower with building_unit
      final matchesTower = visitor.unitDetails.building_unit != null &&
          visitor.unitDetails.building_unit!
              .toLowerCase()
              .startsWith(towerName.toLowerCase());

      return matchesSearch && matchesTower;
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

    if (filteredApprovals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty
                  ? "No results found for '$searchQuery'"
                  : "No approvals found for $towerName",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xffF44336).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('dd MMM, yyyy').format(
                      DateTime.parse(dateKey),
                    ),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: const Color(0xffF44336),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
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
      case "allowed_by_gatekeeper":
        return RequestType.allowByGatekeeper;
      default:
        return RequestType.rejected;
    }
  }

  Future<void> _initializeTimer() async {
    log("Initializing timer for visitor ${widget.visitorInfo.visitorLogId}");

    // Store context in local variable to avoid BuildContext across async gaps
    final currentContext = context;

    if (!mounted) return;

    await _timerService.loadTimerState(
        widget.visitorInfo.visitorLogId ?? 0, currentContext);

    if (mounted) setState(() {});
  }

  Future<void> _handleRetry(BuildContext context) async {
    if (_isLoading) return;

    final visitorLogId = widget.visitorInfo.visitorLogId ?? 0;

    if (_timerService.hasRetried(visitorLogId)) {
      _showSnackBar('Retry already attempted for this visitor', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    RequestType requestType =
        _getRequestType(widget.visitorInfo.allowStatus.toLowerCase());

    if (requestType == RequestType.approved ||
        requestType == RequestType.allowByGatekeeper) {
      _showSnackBar('Visitor is already allowed', isError: false);
      setState(() => _isLoading = false);
      return;
    } else if (requestType == RequestType.rejected) {
      _showSnackBar('Visitor has been denied entry', isError: true);
      setState(() => _isLoading = false);
      return;
    } else if (requestType == RequestType.leaveAtGate) {
      _showSnackBar('Visitor is waiting at the gate', isError: false);
      setState(() => _isLoading = false);
      return;
    } else if (requestType == RequestType.notRecheable) {
      _showSnackBar('Visitor is not reachable', isError: true);
      setState(() => _isLoading = false);
      return;
    }

    try {
      await _sendFcmNotification(); // Fallback to REST API

      log("Trying to send notification via socket for visitor $visitorLogId");
      // Try to send notification via socket first
      await _sendNotificationViaSocket();

      if (mounted) {
        _timerService.markRetryAttempt(visitorLogId); // Mark Retry as Attempted

        // Use a separate function to handle the timer to avoid BuildContext issues
        // We don't pass the context directly to avoid BuildContext across async gaps
        _startTimerSafely(visitorLogId);
      }
    } catch (e) {
      log("❌ Error in _handleRetry: $e");
      _showSnackBar('Failed to resend notification', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startTimerSafely(int visitorLogId) async {
    // Only proceed if the widget is still mounted
    if (!mounted) return;

    // Create a new endTime directly without using context
    final endTime = DateTime.now()
        .add(const Duration(seconds: 60)); // Use default 60 seconds

    // Update the timer state directly
    _timerService._timers[visitorLogId] = TimerState(
      endTime: endTime,
      isRetryEnabled: false,
    );

    // Save the timer state
    await _timerService.saveTimerState(visitorLogId, endTime);

    // Update the UI if still mounted
    if (mounted) {
      setState(() {});
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
      'user_id': widget.visitorInfo.memberInfo.memberId.toString(),
      'visitor_count': "1",
      'purpose':
          widget.visitorInfo.purposeCategoryName?.toLowerCase() ?? "general",
      'member_mobile_number':
          widget.visitorInfo.memberInfo.mobileNumber ?? "917378880544",
      'visitor_id': widget.visitorInfo.visitorId.toString(),
      'purpose_category':
          widget.visitorInfo.visitorPurposeCategoryId.toString(),
      'visitor_log_id': widget.visitorInfo.visitorLogId.toString(),
      'coming_from': widget.visitorInfo.visitorComingFrom ?? "Bandra",
      'member_id': widget.visitorInfo.memberInfo.memberId.toString(),
      'self_check_in': "false",
      'company_name': widget.visitorInfo.companyName, // Include company name
      'file': widget.visitorInfo.visitorImage, // Include visitor image
      'socket_request': true // Add flag to identify socket requests
    };
  }

  Future<void> _sendFcmNotification() async {
    final formattedInTime =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    try {
      // Use the same data structure as the socket request
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
        'purpose_category':
            widget.visitorInfo.visitorPurposeCategoryId.toString(),
        'visitor_log_id': widget.visitorInfo.visitorLogId.toString(),
        'coming_from': widget.visitorInfo.visitorComingFrom ?? "Bandra",
        'member_id': widget.visitorInfo.memberInfo.memberId.toString(),
        "self_check_in": "false",
        "company_name": widget.visitorInfo.companyName,
        "file": widget.visitorInfo.visitorImage
      };

      log("📨 Sending FCM Notification with Data: $requestData");

      final response = await Dio().post(
        '${ApiUrls.gateBaseUrl}/visitor/sendFcmNotification',
        options: Options(headers: {"Content-Type": "application/json"}),
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

  Future<void> _handleFcmResponse(dynamic responseData) async {
    try {
      if (responseData == null) {
        log("❌ FCM Response data is null");
        return;
      }

      log("📩 Full FCM Response: $responseData");

      // Check if the response indicates a successful call initiation via Twilio
      if (responseData is String && responseData.contains("<?xml")) {
        log("📞 Received Twilio XML response");
        _showSnackBar("Call initiated to member successfully", isError: false);
        return;
      }

      // Check if the response is a map with success and message fields
      if (responseData is Map &&
          responseData["success"] == true &&
          responseData["message"]
                  ?.toString()
                  .contains("call initiated successfully") ==
              true) {
        log("✅ Call initiated successfully via Twilio");
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

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    myFluttertoast(
      msg: message,
      backgroundColor: isError ? Colors.red : Colors.green,
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
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => VisitorDetailsScreen2(
                              visitorLog: visitorInfo,
                              isFromMissedApprovalScreen: true,
                            )));
              },
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
              subtitle: Row(
                children: [
                  Icon(
                    _getPurposeIcon(visitorInfo.purposeSubCategoryName ??
                        visitorInfo.purposeCategoryName),
                    size: 18, // Reduced size for alignment
                    color: Colors.grey[600], // Greyish color
                  ),
                  const SizedBox(width: 6), // Spacing between icon and text
                  Text(
                    "${_capitalizeFirstLetter(visitorInfo.purposeSubCategoryName ?? visitorInfo.purposeCategoryName ?? "")} - ${visitorInfo.unitDetails.building_unit}",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 14, // Ensures text size consistency
                          color: Colors.grey[600], // Greyish color
                        ),
                  ),
                ],
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
        backgroundColor:
            Theme.of(context).primaryColor.withAlpha(25), // ~0.1 opacity
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
        final timerService = TimerService(); // Use singleton instance
        final timerState = timerService.getTimerState(widget.visitorLogId);
        if (timerState == null) return const SizedBox.shrink();

        final hasRetried = timerService.hasRetried(widget.visitorLogId);
        final now = DateTime.now();
        final remaining = timerState.endTime.difference(now);
        final isEnabled =
            remaining.isNegative || (timerState.isRetryEnabled && !hasRetried);

        final allowStatus = widget.visitorInfo.allowStatus.toLowerCase();
        // Get the status for UI rendering

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ✅ Case: Visitor has Left (LEAVE)
              if (allowStatus == "leave")
                _isImageUploaded
                    ? Row(
                        children: [
                          const Icon(Icons.directions_walk,
                              color: Colors.brown, size: 20),
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
                                        child: CircularProgressIndicator(
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
              else if (allowStatus == "allowed" ||
                  allowStatus == "always_allowed" ||
                  allowStatus == "allowed_by_gatekeeper")
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 15),
                    const SizedBox(width: 8),
                    Text(
                      "Visitor has been allowed.",
                      style: Theme.of(context).textTheme.labelMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                    ),
                  ],
                )

              // ✅ Case: Visitor Declined
              else if (allowStatus == "declined" || allowStatus == "denied")
                Row(
                  children: [
                    const Icon(Icons.cancel, color: Colors.red, size: 15),
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
                        const Icon(Icons.hourglass_empty,
                            color: Colors.orange, size: 15),
                        const SizedBox(width: 8),
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
                        ? SizedBox(
                            width: MediaQuery.of(context).size.width * 0.2,
                            child: RetryButton(
                              onRetry: widget.onRetry,
                              isEnabled: isEnabled && !widget.isLoading,
                              isLoading: widget.isLoading,
                            ),
                          )
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
                        color: Colors.grey, size: 15),
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
                      child: RetryButton(
                        onRetry: widget.onRetry,
                        isEnabled: isEnabled && !widget.isLoading,
                        isLoading: widget.isLoading,
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
        );
      },
    );
  }
}
