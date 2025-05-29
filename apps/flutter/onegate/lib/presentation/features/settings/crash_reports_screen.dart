import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/services/crash_reporting/crash_reporter_service.dart';
import 'package:flutter_onegate/services/crash_reporting/models/crash_models.dart';
import 'package:ionicons/ionicons.dart';

/// Screen for viewing crash reports and error analytics
class CrashReportsScreen extends StatefulWidget {
  const CrashReportsScreen({Key? key}) : super(key: key);

  @override
  State<CrashReportsScreen> createState() => _CrashReportsScreenState();
}

class _CrashReportsScreenState extends State<CrashReportsScreen> {
  final CrashReporterService _crashService = CrashReporterService();
  
  bool _isLoading = true;
  List<CrashReport> _crashes = [];
  Map<String, dynamic> _statistics = {};
  String _selectedFilter = 'all';
  
  @override
  void initState() {
    super.initState();
    _loadCrashData();
  }

  Future<void> _loadCrashData() async {
    setState(() => _isLoading = true);
    
    try {
      final crashes = _crashService.getAllCrashReports();
      final stats = _crashService.getCrashStatistics();
      
      setState(() {
        _crashes = crashes;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading crash data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<CrashReport> get _filteredCrashes {
    switch (_selectedFilter) {
      case 'fatal':
        return _crashes.where((c) => c.isFatal).toList();
      case 'non_fatal':
        return _crashes.where((c) => !c.isFatal).toList();
      case 'recent':
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        return _crashes.where((c) => c.timestamp.isAfter(yesterday)).toList();
      default:
        return _crashes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageTitle: 'Crash Reports',
      pageBody: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatisticsCard(),
                const SizedBox(height: 16),
                _buildFilterChips(),
                const SizedBox(height: 16),
                _buildCrashList(),
              ],
            ),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Ionicons.analytics_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Crash Statistics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Crashes',
                    '${_statistics['totalCrashes'] ?? 0}',
                    Colors.blue,
                    Ionicons.bug_outline,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Fatal Crashes',
                    '${_statistics['fatalCrashes'] ?? 0}',
                    Colors.red,
                    Ionicons.skull_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Last 24h',
                    '${_statistics['crashes24h'] ?? 0}',
                    Colors.orange,
                    Ionicons.time_outline,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Unique Errors',
                    '${_statistics['uniqueErrors'] ?? 0}',
                    Colors.green,
                    Ionicons.layers_outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'All Crashes'},
      {'key': 'fatal', 'label': 'Fatal Only'},
      {'key': 'non_fatal', 'label': 'Non-Fatal'},
      {'key': 'recent', 'label': 'Last 24h'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter['label']!),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter['key']!;
                });
              },
              selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              checkmarkColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCrashList() {
    final filteredCrashes = _filteredCrashes;
    
    if (filteredCrashes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Ionicons.checkmark_circle_outline,
                size: 64,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              Text(
                'No crashes found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Your app is running smoothly!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: filteredCrashes.map((crash) => _buildCrashCard(crash)).toList(),
    );
  }

  Widget _buildCrashCard(CrashReport crash) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: crash.severity.colorHex.startsWith('#')
              ? Color(int.parse(crash.severity.colorHex.substring(1), radix: 16) + 0xFF000000)
              : Colors.red,
          child: Icon(
            crash.isFatal ? Ionicons.skull : Ionicons.warning,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          crash.errorType,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              crash.errorMessage.length > 100
                  ? '${crash.errorMessage.substring(0, 100)}...'
                  : crash.errorMessage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Ionicons.time_outline, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  crash.formattedTimestamp,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                if (crash.crashCount > 1) ...[
                  Icon(Ionicons.repeat_outline, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${crash.crashCount}x',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Icon(Ionicons.chevron_forward),
        onTap: () => _showCrashDetails(crash),
      ),
    );
  }

  void _showCrashDetails(CrashReport crash) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Crash Details',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyCrashDetails(crash),
                    icon: Icon(Ionicons.copy_outline),
                    tooltip: 'Copy crash details',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Ionicons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailRow('Error Type', crash.errorType),
                    _buildDetailRow('Fatal', crash.isFatal ? 'Yes' : 'No'),
                    _buildDetailRow('Timestamp', crash.timestamp.toString()),
                    _buildDetailRow('App Version', crash.appVersion),
                    _buildDetailRow('Platform', '${crash.platform} ${crash.osVersion}'),
                    _buildDetailRow('Device', crash.deviceModel),
                    if (crash.userId != null)
                      _buildDetailRow('User ID', crash.userId!),
                    if (crash.gateId != null)
                      _buildDetailRow('Gate ID', crash.gateId!),
                    const SizedBox(height: 16),
                    Text(
                      'Error Message',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(
                        crash.errorMessage,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Stack Trace',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Text(
                        crash.stackTrace,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _copyCrashDetails(CrashReport crash) {
    final details = '''
Crash Report Details:
Error Type: ${crash.errorType}
Fatal: ${crash.isFatal ? 'Yes' : 'No'}
Timestamp: ${crash.timestamp}
App Version: ${crash.appVersion}
Platform: ${crash.platform} ${crash.osVersion}
Device: ${crash.deviceModel}
${crash.userId != null ? 'User ID: ${crash.userId}\n' : ''}${crash.gateId != null ? 'Gate ID: ${crash.gateId}\n' : ''}
Error Message:
${crash.errorMessage}

Stack Trace:
${crash.stackTrace}
''';

    Clipboard.setData(ClipboardData(text: details));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crash details copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
