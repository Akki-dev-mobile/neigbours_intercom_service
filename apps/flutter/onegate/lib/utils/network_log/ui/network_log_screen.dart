import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onegate/utils/network_log/models/network_log.dart';
import 'package:flutter_onegate/utils/network_log/network_log_manager.dart';
import 'package:flutter_onegate/utils/network_log/services/network_log_service.dart';
import 'package:flutter_onegate/utils/network_log/ui/network_log_sync_settings.dart';

class NetworkLogScreen extends StatefulWidget {
  const NetworkLogScreen({Key? key}) : super(key: key);

  @override
  State<NetworkLogScreen> createState() => _NetworkLogScreenState();
}

class _NetworkLogScreenState extends State<NetworkLogScreen>
    with SingleTickerProviderStateMixin {
  final NetworkLogManager _logManager = NetworkLogManager();
  final NetworkLogService _logService = NetworkLogService();
  String? _selectedMethod;
  bool? _hasError;
  bool _isSyncing = false; // Track sync status
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _triggerManualSync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final success = await _logManager.triggerManualSync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                success ? 'Logs synced successfully' : 'Failed to sync logs'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context
                .tr('Error syncing logs: {error}', params: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Network Logs')),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: context.tr('Sync Settings'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NetworkLogSyncSettings(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _logService.clearLogs();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr('Logs cleared'))),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<NetworkLog>>(
        valueListenable: _logService.logs,
        builder: (context, logs, _) {
          final filteredLogs = _getFilteredLogs(logs);

          if (filteredLogs.isEmpty) {
            return Center(
              child: Text(context.tr('No network logs available')),
            );
          }

          return ListView.builder(
            itemCount: filteredLogs.length,
            itemBuilder: (context, index) {
              final log = filteredLogs[index];
              return _buildLogItem(log);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSyncing ? null : _triggerManualSync,
        tooltip: context.tr('Sync Logs'),
        child: _isSyncing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: DashboardLoaderIcon(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.sync),
      ),
    );
  }

  List<NetworkLog> _getFilteredLogs(List<NetworkLog> logs) {
    return logs.where((log) {
      bool matchesMethod =
          _selectedMethod == null || log.method == _selectedMethod;
      bool matchesError = _hasError == null ||
          (_hasError! && log.error != null) ||
          (!_hasError! && log.error == null);

      return matchesMethod && matchesError;
    }).toList();
  }

  Widget _buildLogItem(NetworkLog log) {
    final statusColor = Color(log.statusColor);
    final statusText =
        log.statusCode != null ? '${log.statusCode}' : context.tr('Error');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => _showLogDetails(log),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      log.method,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    log.formattedDuration,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    log.formattedTimestamp,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                log.url,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (log.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Error: ${log.error}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(context.tr('Filter Logs')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String?>(
                    decoration: InputDecoration(
                      labelText: context.tr('HTTP Method'),
                    ),
                    value: _selectedMethod,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(context.tr('All')),
                      ),
                      ...['GET', 'POST', 'PUT', 'DELETE', 'PATCH']
                          .map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(method),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedMethod = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<bool?>(
                    decoration: InputDecoration(
                      labelText: context.tr('Status'),
                    ),
                    value: _hasError,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(context.tr('All')),
                      ),
                      DropdownMenuItem(
                        value: false,
                        child: Text(context.tr('Success')),
                      ),
                      DropdownMenuItem(
                        value: true,
                        child: Text(context.tr('Error')),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _hasError = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(context.tr('Cancel')),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedMethod = null;
                      _hasError = null;
                    });
                  },
                  child: Text(context.tr('Reset')),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // The filter is applied in the ValueListenableBuilder
                    this.setState(() {});
                  },
                  child: Text(context.tr('Apply')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogDetails(NetworkLog log) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(log.shortDescription),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Expanded(
                  child: DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        TabBar(
                          controller: _tabController,
                          tabs: [
                            Tab(text: context.tr('Request')),
                            Tab(text: context.tr('Response')),
                            Tab(text: context.tr('Overview')),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildRequestTab(log),
                              _buildResponseTab(log),
                              _buildOverviewTab(log),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestTab(NetworkLog log) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context.tr('URL')),
          _buildCopyableText(log.url),
          const SizedBox(height: 16),
          _buildSectionTitle(context.tr('Method')),
          Text(log.method),
          const SizedBox(height: 16),
          _buildSectionTitle(context.tr('Headers')),
          _buildJsonViewer(log.headers),
          if (log.requestBody != null) ...[
            const SizedBox(height: 16),
            _buildSectionTitle(context.tr('Body')),
            _buildJsonViewer(log.requestBody),
          ],
        ],
      ),
    );
  }

  Widget _buildResponseTab(NetworkLog log) {
    if (log.error != null && log.statusCode == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context.tr('Error')),
            Text(
              log.error!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context.tr('Status')),
          Text(
            '${log.statusCode}',
            style: TextStyle(
              color: log.statusCode! >= 400 ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionTitle(context.tr('Body')),
          _buildJsonViewer(log.responseBody),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(NetworkLog log) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context.tr('Time')),
          Text('${log.timestamp}'),
          const SizedBox(height: 16),
          _buildSectionTitle(context.tr('Duration')),
          Text(log.formattedDuration),
          const SizedBox(height: 16),
          _buildSectionTitle(context.tr('Method')),
          Text(log.method),
          const SizedBox(height: 16),
          _buildSectionTitle(context.tr('URL')),
          _buildCopyableText(log.url),
          const SizedBox(height: 16),
          _buildSectionTitle(context.tr('Status')),
          Text(
            log.statusCode != null ? '${log.statusCode}' : context.tr('Error'),
            style: TextStyle(
              color: log.statusCode == null || log.statusCode! >= 400
                  ? Colors.red
                  : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionTitle(context.tr('Gate ID')),
          Text(log.gateId.isEmpty ? context.tr('Not specified') : log.gateId),
          const SizedBox(height: 16),
          _buildSectionTitle(context.tr('Environment')),
          Text(log.environment.isEmpty
              ? context.tr('Not specified')
              : log.environment),
          const SizedBox(height: 16),
          _buildSectionTitle(context.tr('Sync Status')),
          Row(
            children: [
              Icon(
                log.synced ? Icons.check_circle : Icons.sync,
                color: log.synced ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                log.synced
                    ? context.tr('Synced to server')
                    : context.tr('Not synced'),
                style: TextStyle(
                  color: log.synced ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildCopyableText(String text) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Copied to clipboard'))),
        );
      },
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.blue,
              ),
            ),
          ),
          const Icon(Icons.copy, size: 16),
        ],
      ),
    );
  }

  Widget _buildJsonViewer(dynamic content) {
    if (content == null) {
      return Text(context.tr('No content'));
    }

    try {
      dynamic jsonData;
      if (content is String) {
        try {
          jsonData = json.decode(content);
        } catch (e) {
          return Text(content);
        }
      } else {
        jsonData = content;
      }

      final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonData);
      return InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: prettyJson));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('Copied to clipboard'))),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  prettyJson,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(Icons.copy, size: 16),
            ],
          ),
        ),
      );
    } catch (e) {
      return Text(content.toString());
    }
  }
}
