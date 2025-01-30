import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:common_widgets/common_widgets.dart';

class MissedApprovalsScreen extends StatelessWidget {
  final remoteDataSource = RemoteDataSource(
    DioSingleton.instance1,
    DioSingleton.instance2,
    DioSingleton.instance3,
  );

  MissedApprovalsScreen();

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageTitle: 'Missed Approvals',
      pageBody: FutureBuilder<List<dynamic>>(
        future: remoteDataSource.fetchApprovals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load approvals: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No missed approvals found.'),
            );
          }

          final missedApprovals =
              snapshot.data!.map((data) => VisitorInfo.fromJson(data)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: missedApprovals.length,
            itemBuilder: (context, index) {
              return MissedApprovalItem(
                visitorInfo: missedApprovals[index],
              );
            },
          );
        },
      ),
    );
  }
}

class TimerManager {
  static final TimerManager _instance = TimerManager._internal();

  factory TimerManager() => _instance;

  TimerManager._internal();

  final Map<int, Timer> _timers = {};
  final Map<int, ValueNotifier<int>> _secondsRemaining = {};
  final Map<int, ValueNotifier<bool>> _isRetryEnabled = {};

  void startTimer(int visitorLogId) {
    print("Starting timer for visitor $visitorLogId"); // Debug print

    // Cancel existing timer if any
    _timers[visitorLogId]?.cancel();

    // Initialize notifiers if they don't exist
    _secondsRemaining[visitorLogId] ??= ValueNotifier<int>(120);
    _isRetryEnabled[visitorLogId] ??= ValueNotifier<bool>(false);

    // Reset values
    _secondsRemaining[visitorLogId]!.value = 120;
    _isRetryEnabled[visitorLogId]!.value = false;
    _saveTimerState(visitorLogId); // Save initial state

    // Start new timer
    _timers[visitorLogId] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining[visitorLogId]!.value > 0) {
        _secondsRemaining[visitorLogId]!.value--;
        _saveTimerState(visitorLogId);
        print(
            "Timer tick: ${_secondsRemaining[visitorLogId]!.value}"); // Debug print
      } else {
        timer.cancel();
        _isRetryEnabled[visitorLogId]!.value = true;
        _saveTimerState(visitorLogId);
        print("Timer expired for visitor $visitorLogId"); // Debug print
      }
    });
  }

  ValueNotifier<int> getSecondsRemaining(int visitorLogId) {
    if (_secondsRemaining[visitorLogId] == null) {
      _secondsRemaining[visitorLogId] = ValueNotifier<int>(120);
      startTimer(visitorLogId); // Start timer if it doesn't exist
    }
    return _secondsRemaining[visitorLogId]!;
  }

  ValueNotifier<bool> getIsRetryEnabled(int visitorLogId) {
    _isRetryEnabled[visitorLogId] ??= ValueNotifier<bool>(false);
    return _isRetryEnabled[visitorLogId]!;
  }

  Future<void> _saveTimerState(int visitorLogId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'timer_$visitorLogId', _secondsRemaining[visitorLogId]!.value);
    await prefs.setBool(
        'retry_$visitorLogId', _isRetryEnabled[visitorLogId]!.value);
  }

  Future<void> loadTimerState(int visitorLogId) async {
    print("Loading timer state for visitor $visitorLogId");
    final prefs = await SharedPreferences.getInstance();
    final savedSeconds = prefs.getInt('timer_$visitorLogId');
    final savedRetry = prefs.getBool('retry_$visitorLogId') ?? false;

    if (savedSeconds != null && savedSeconds > 0 && !savedRetry) {
      _secondsRemaining[visitorLogId] = ValueNotifier<int>(savedSeconds);
      _isRetryEnabled[visitorLogId] = ValueNotifier<bool>(false);
      startTimer(visitorLogId);
    } else {
      // If no saved state or timer expired, start fresh
      startTimer(visitorLogId);
    }
  }

  void dispose(int visitorLogId) {
    _timers[visitorLogId]?.cancel();
    _timers.remove(visitorLogId);
    _secondsRemaining.remove(visitorLogId);
    _isRetryEnabled.remove(visitorLogId);
  }
}

class MissedApprovalItem extends StatefulWidget {
  final VisitorInfo visitorInfo;

  const MissedApprovalItem({
    Key? key,
    required this.visitorInfo,
  }) : super(key: key);

  @override
  State<MissedApprovalItem> createState() => _MissedApprovalItemState();
}

class _MissedApprovalItemState extends State<MissedApprovalItem> {
  final Dio _dio = Dio();
  final TimerManager _timerManager = TimerManager();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTimer();
  }

  Future<void> _initializeTimer() async {
    if (!_isInitialized) {
      await _timerManager.loadTimerState(widget.visitorInfo.visitorLogId);
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _timerManager.dispose(widget.visitorInfo.visitorLogId);
    super.dispose();
  }

  Future<void> _sendFcmNotification() async {
    try {
      final requestData = {
        'member_mobile_number': "918452060059",
        'visitor_id': widget.visitorInfo.visitorId,
        "member_id": "29",
        'purpose_category': 1.toString(),
      };

      final response = await _dio.post(
        '${ApiUrls.gateBaseUrl}/visitor/exotel/call',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: requestData,
      );

      if (response.statusCode == 200) {
        Fluttertoast.showToast(
          msg: "Notification Resent Successfully",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        _timerManager.startTimer(widget.visitorInfo.visitorLogId);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Failed to resend notification",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      print("Error sending FCM notification: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shadowColor: theme.shadowColor.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.dividerColor.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Hero(
                  tag: 'visitor_${widget.visitorInfo.visitorId}',
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: CircleAvatar(
                      radius: 27,
                      backgroundImage:
                          widget.visitorInfo.visitorImage.isNotEmpty
                              ? NetworkImage(widget.visitorInfo.visitorImage)
                              : null,
                      backgroundColor: theme.cardColor,
                      child: widget.visitorInfo.visitorImage.isEmpty
                          ? Text(
                              widget.visitorInfo.visitorName.isNotEmpty
                                  ? widget.visitorInfo.visitorName[0]
                                      .toUpperCase()
                                  : 'G',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                title: Text(
                  widget.visitorInfo.visitorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .primaryColor
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Symbols.apartment,
                                color: Theme.of(context).primaryColor,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Guest',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.person_outline,
                      'Member: ${widget.visitorInfo.memberInfo.name}',
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black87,
                    ),
                    _buildInfoRow(
                      Icons.location_on_outlined,
                      'Gate: ${widget.visitorInfo.inGate}',
                      Theme.of(context).textTheme.bodyMedium?.color ??
                          Colors.black54,
                    ),
                    _buildInfoRow(
                      Icons.access_time,
                      'Time: ${DateFormat('hh:mm a').format(DateTime.parse(widget.visitorInfo.logCreatedAt))}',
                      Theme.of(context).textTheme.bodyMedium?.color ??
                          Colors.black54,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _timerManager
                          .getIsRetryEnabled(widget.visitorInfo.visitorLogId),
                      builder: (context, isRetryEnabled, _) {
                        final buttonColor = isRetryEnabled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceVariant;
                        final textColor = isRetryEnabled
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant;

                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isRetryEnabled
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.2),
                                      offset: const Offset(0, 2),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : [],
                          ),
                          child: ElevatedButton.icon(
                            onPressed:
                                isRetryEnabled ? _sendFcmNotification : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonColor,
                              foregroundColor: textColor,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(
                              isRetryEnabled
                                  ? Icons.refresh_rounded
                                  : Icons.hourglass_empty_rounded,
                              size: 20,
                            ),
                            label: Text(
                              isRetryEnabled ? 'Retry Now' : 'Processing',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: _timerManager
                          .getSecondsRemaining(widget.visitorInfo.visitorLogId),
                      builder: (context, secondsRemaining, _) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: _timerManager.getIsRetryEnabled(
                              widget.visitorInfo.visitorLogId),
                          builder: (context, isRetryEnabled, _) {
                            final timerColor = isRetryEnabled
                                ? Color(0xFFDC2626) // Red for expired state
                                : Color(0xFF2563EB); // Blue for active state

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: timerColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: timerColor.withOpacity(0.2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: timerColor.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isRetryEnabled
                                        ? Icons.timer_off_outlined
                                        : Icons.timer_outlined,
                                    size: 20,
                                    color: timerColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isRetryEnabled
                                        ? 'Expired'
                                        : '${(secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(secondsRemaining % 60).toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: timerColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// Define data classes for better type safety
class VisitorInfo {
  final int visitorId;
  final String visitorName;
  final String visitorMobile;
  final String visitorImage;
  final String allowStatus;
  final int visitorLogId;
  final int companyId;
  final String inGate;
  final String logCreatedAt;
  final MemberInfo memberInfo;
  final String? visitorComingFrom;
  final int? visitorPurposeCategoryId;

  VisitorInfo({
    required this.visitorId,
    required this.visitorName,
    required this.visitorMobile,
    required this.visitorImage,
    required this.allowStatus,
    required this.visitorLogId,
    required this.companyId,
    required this.inGate,
    required this.logCreatedAt,
    required this.memberInfo,
    this.visitorComingFrom,
    this.visitorPurposeCategoryId,
  });

  factory VisitorInfo.fromJson(Map<String, dynamic> json) {
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
      memberInfo: MemberInfo(
        name: json['member_name']?.toString() ?? '',
        mobileNumber: json['memb_mobile_number']?.toString(),
        email: json['memb_email']?.toString(),
        memberId: _parseToInt(json['member_id'] ?? "") ?? 0,
        unitId: _parseToInt(json['unit_id'] ?? "") ?? 0,
      ),
      visitorComingFrom: json['visitor_coming_from']?.toString(),
      visitorPurposeCategoryId:
          _parseToInt(json['visitor_purpose_category_id']),
    );
  }

  // Helper method to safely parse various types to int
  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}

class MemberInfo {
  final String name;
  final String? mobileNumber;
  final String? email;
  final int? unitId;
  final int? memberId;

  MemberInfo(
      {required this.name,
      this.mobileNumber,
      this.email,
      this.unitId,
      this.memberId});
}
