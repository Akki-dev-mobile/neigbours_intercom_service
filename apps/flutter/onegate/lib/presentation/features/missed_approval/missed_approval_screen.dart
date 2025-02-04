import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/request_permission/ui/request_permission_view.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Timer Service
class TimerState {
  final DateTime endTime;
  final bool isRetryEnabled;

  TimerState({required this.endTime, required this.isRetryEnabled});
}

class TimerService {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  TimerService._internal();

  final Map<int, TimerState> _timers = {};
  final _duration = const Duration(minutes: 2);

  Future<void> startTimer(int visitorLogId) async {
    final endTime = DateTime.now().add(_duration);
    _timers[visitorLogId] = TimerState(
      endTime: endTime,
      isRetryEnabled: false,
    );
    await _saveTimerState(visitorLogId, endTime);
  }

  Future<void> _saveTimerState(int visitorLogId, DateTime endTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('timer_$visitorLogId', endTime.toIso8601String());
  }

  Future<void> loadTimerState(int visitorLogId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedEndTime = prefs.getString('timer_$visitorLogId');

    if (savedEndTime != null) {
      final endTime = DateTime.parse(savedEndTime);
      if (endTime.isAfter(DateTime.now())) {
        _timers[visitorLogId] = TimerState(
          endTime: endTime,
          isRetryEnabled: false,
        );
      } else {
        _timers[visitorLogId] = TimerState(
          endTime: DateTime.now(),
          isRetryEnabled: true,
        );
      }
    } else {
      await startTimer(visitorLogId);
    }
  }

  TimerState? getTimerState(int visitorLogId) => _timers[visitorLogId];

  void dispose(int visitorLogId) {
    _timers.remove(visitorLogId);
  }

  void disposeAll() {
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
    return ElevatedButton.icon(
      onPressed: isEnabled ? onRetry : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      icon: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(
              Icons.refresh,
              color: Colors.black,
            ),
      label: Text(
        isLoading ? 'Sending...' : 'Retry Notification',
        style: Theme.of(context).textTheme.bodyLarge,
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
      return const Text(
        'Time ELapsed',
        style: TextStyle(
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

// Data Models
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

  VisitorInfo({
    required this.visitorId,
    required this.visitorName,
    required this.visitorMobile,
    required this.visitorImage,
    required this.allowStatus,
    this.visitorLogId,
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
        memberId: _parseToInt(json['member_id']),
        unitId: _parseToInt(json['unit_id']),
      ),
      visitorComingFrom: json['visitor_coming_from']?.toString(),
      visitorPurposeCategoryId:
          _parseToInt(json['visitor_purpose_category_id']),
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
}

class MemberInfo {
  final String name;
  final String? mobileNumber;
  final String? email;
  final int? unitId;
  final int? memberId;

  MemberInfo({
    required this.name,
    this.mobileNumber,
    this.email,
    this.unitId,
    this.memberId,
  });
}

// Main Screen
class MissedApprovalsScreen extends StatelessWidget {
  final RemoteDataSource remoteDataSource;

  const MissedApprovalsScreen({
    Key? key,
    required this.remoteDataSource,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Missed Approvals',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: FutureBuilder<List<VisitorInfo>>(
        future: remoteDataSource.fetchApprovals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No missed approvals'));
          }

          return ApprovalsList(approvals: snapshot.data!);
        },
      ),
    );
  }
}

// List Widget
class ApprovalsList extends StatelessWidget {
  final List<VisitorInfo> approvals;

  const ApprovalsList({
    Key? key,
    required this.approvals,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Filter out visitors who are already allowed
    final filteredApprovals = approvals
        .where((visitor) =>
    visitor.allowStatus.toLowerCase() != "allowed" &&
        visitor.allowStatus.toLowerCase() != "always_allowed")
        .toList();

    // Sorting by logCreatedAt in descending order (newest first)
    filteredApprovals.sort((a, b) =>
        DateTime.parse(b.logCreatedAt).compareTo(DateTime.parse(a.logCreatedAt)));

    // If there are no pending approvals, show a message
    if (filteredApprovals.isEmpty) {
      return const Center(
        child: Text(
          "No pending approvals",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredApprovals.length,
      itemBuilder: (context, index) {
        return MissedApprovalCard(
          visitorInfo: filteredApprovals[index],
          key: ValueKey(filteredApprovals[index].visitorLogId),
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
    await _timerService.loadTimerState(widget.visitorInfo.visitorLogId ?? 0);
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

  Future<void> _handleRetry() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    RequestType requestType =
    _getRequestType(widget.visitorInfo.allowStatus.toLowerCase());

    if (requestType == RequestType.approved ||
        requestType == RequestType.allowByGatekeeper) {
      _showSnackBar('Visitor is already allowed', isError: false);
      await _timerService.startTimer(widget.visitorInfo.visitorLogId ?? 0);
      setState(() {}); // Ensure UI updates
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

    // If visitor is not already allowed, proceed with retry logic
    try {
      final dio = Dio();
      final response = await dio.post(
        '${ApiUrls.gateBaseUrl}/visitor/exotel/call',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: {
          'member_mobile_number': 8452060059,
          'visitor_id': widget.visitorInfo.visitorId,
          'member_id': widget.visitorInfo.memberInfo.memberId,
          'visitor_log_id': widget.visitorInfo.visitorLogId,
          'purpose_category': widget.visitorInfo.visitorPurposeCategoryId.toString(),
        },
      );

      if (response.statusCode == 200) {
        await _timerService.startTimer(widget.visitorInfo.visitorLogId ?? 0);
        setState(() {});
        _showSnackBar('Notification resent successfully', isError: false);
      }
    } catch (e) {
      await _timerService.startTimer(widget.visitorInfo.visitorLogId ?? 0);
      _showSnackBar('Failed to resend notification', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          VisitorInfoSection(visitorInfo: widget.visitorInfo),
          const Divider(height: 1),
          TimerActionSection(
            visitorInfo: widget.visitorInfo,
            visitorLogId: widget.visitorInfo.visitorLogId ?? 0,
            onRetry: _handleRetry,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }
}

// Info Section Widget
class VisitorInfoSection extends StatelessWidget {
  final VisitorInfo visitorInfo;

  const VisitorInfoSection({
    Key? key,
    required this.visitorInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VisitorAvatar(visitorInfo: visitorInfo),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visitorInfo.visitorName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Member: ${visitorInfo.memberInfo.name}',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  'Gate: ${visitorInfo.inGate}',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  'Time: ${DateFormat('hh:mm a').format(DateTime.parse(visitorInfo.logCreatedAt))}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
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
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
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
        style: const TextStyle(fontSize: 24),
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

        final now = DateTime.now();
        final remaining = timerState.endTime.difference(now);
        final isEnabled = remaining.isNegative || timerState.isRetryEnabled;

        final isVisitorAllowed =
            visitorInfo.allowStatus.toLowerCase() == "allowed" ||
                visitorInfo.allowStatus.toLowerCase() == "always_allowed";

        return Padding(
          padding: const EdgeInsets.all(16),
          child: isVisitorAllowed
              ? Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Text(
                "Visitor allowed",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          )
              : Row(
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
        );
      },
    );
  }
}


