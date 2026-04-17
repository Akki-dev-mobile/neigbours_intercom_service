import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';

class CallHistoryScreen extends StatefulWidget {
  final String fromNumber;

  const CallHistoryScreen({Key? key, required this.fromNumber})
      : super(key: key);

  @override
  _CallHistoryScreenState createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final RemoteDataSource remoteDataSource = RemoteDataSource();
  bool _isLoading = true;
  List<dynamic> _callLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchCallLogs();
  }

  Future<void> _fetchCallLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await remoteDataSource.getCallHistory(widget.fromNumber);
      setState(() {
        _callLogs = logs;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tr('Failed to load call logs: {error}',
                params: {'error': '$e'}))),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showContactDetailsBottomSheet(dynamic log) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.1),
                child: Text(
                  (log['member_name'] ?? log['phone_number'] ?? '-')[0]
                      .toUpperCase(),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                log['member_name'] ?? context.tr('Unknown Contact'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Phone Number with Copy Option
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    log['to_number'] ?? context.tr('N/A'),
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      if (log['phone_number'] != null) {
                        Clipboard.setData(
                          ClipboardData(text: log['phone_number']),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.tr('Phone number copied')),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDetailChip(
                    icon: Icons.calendar_today,
                    label: _formatDateTime(log['created_at'] ?? ''),
                  ),
                  _buildDetailChip(
                    icon: Icons.access_time,
                    label: '${log['call_duration'] ?? 0} sec',
                  ),
                  _buildDetailChip(
                    icon: _getCallTypeIcon(log['call_type'] ?? ''),
                    label: context.tr('INTERCOM'),
                    color: _getCallTypeColor(log['call_type'] ?? ''),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              CustomLargeBtn(
                  text: context.tr('Call Back'),
                  onPressed: () async {
                    Navigator.of(context).pop();

                    // Close bottom sheet
                    Navigator.of(context).pop();
                    remoteDataSource.callMember(log['to_number'], context,
                        name: log["member_name"]);
                  })
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 300.ms)
            .moveY(begin: 50, end: 0, duration: 300.ms);
      },
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: color ?? Colors.grey.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCallTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'incoming':
        return Icons.call_received;
      case 'outgoing':
        return Icons.call_made;
      case 'missed':
        return Icons.call_missed;
      default:
        return Icons.call;
    }
  }

  Color _getCallTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'incoming':
        return Colors.green;
      case 'outgoing':
        return Colors.blue;
      case 'missed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      if (dateTime.isAfter(today)) {
        return 'Today, ${DateFormat('h:mm a').format(dateTime)}';
      } else if (dateTime.isAfter(yesterday)) {
        return 'Yesterday, ${DateFormat('h:mm a').format(dateTime)}';
      } else {
        return DateFormat('MMM d, h:mm a').format(dateTime);
      }
    } catch (e) {
      return dateTimeString;
    }
  }

  Widget _buildCallLogItem(dynamic log) {
    return GestureDetector(
      onTap: () => _showContactDetailsBottomSheet(log),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor:
                _getCallTypeColor(log['call_type'] ?? '').withOpacity(0.1),
            child: Icon(
              _getCallTypeIcon(log['call_type'] ?? ''),
              color: _getCallTypeColor(log['call_type'] ?? ''),
            ),
          ),
          title: Text(
            log['member_name'] ?? log['phone_number'] ?? 'Unknown',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                _formatDateTime(log['created_at'] ?? ''),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              if (log['call_duration'] != null)
                Text(
                  'Duration: ${log['call_duration']} sec',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(
              Icons.info_outline,
              color: Colors.black,
            ),
            onPressed: () => _showContactDetailsBottomSheet(log),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .moveY(begin: 20, end: 0, duration: 500.ms);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Call History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCallLogs,
            color: Colors.black,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCallLogs,
        child: _isLoading
            ? const Center(
                child: DashboardLoaderIcon(
                  color: Colors.black,
                ),
              )
            : _callLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No call history found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _callLogs.length,
                    itemBuilder: (context, index) {
                      return _buildCallLogItem(_callLogs[index]);
                    },
                  ),
      ),
    );
  }
}
