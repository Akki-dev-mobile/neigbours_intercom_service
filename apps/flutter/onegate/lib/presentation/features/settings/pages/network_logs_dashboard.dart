import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';

class NetworkLogsDashboard extends StatefulWidget {
  final String serverUrl;

  const NetworkLogsDashboard({
    Key? key,
    required this.serverUrl,
  }) : super(key: key);

  @override
  State<NetworkLogsDashboard> createState() => _NetworkLogsDashboardState();
}

class _NetworkLogsDashboardState extends State<NetworkLogsDashboard>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _logs = [];
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(Uri.parse(widget.serverUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _logs = data['logs'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load logs: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching logs: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.networkLogsDashboard),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLogs,
            tooltip: AppLocalizations.of(context)!.refreshLogs,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.error,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchLogs,
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      );
    }

    if (_logs.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.noNetworkLogs),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLogs,
      child: ListView.builder(
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          return _buildLogItem(log);
        },
      ),
    );
  }

  Widget _buildLogItem(dynamic log) {
    final statusCode = log['statusCode'];
    final method = log['method'] ?? 'GET';
    final url = log['url'] ?? '';
    final timestamp = log['timestamp'] != null
        ? DateFormat('MMM dd, HH:mm:ss')
            .format(DateTime.parse(log['timestamp']))
        : 'Unknown';
    final duration = log['duration'] != null ? '${log['duration']}ms' : 'N/A';
    final hasError = log['error'] != null;

    Color statusColor = Colors.grey;
    if (statusCode != null) {
      if (statusCode >= 200 && statusCode < 300) {
        statusColor = Colors.green;
      } else if (statusCode >= 300 && statusCode < 400) {
        statusColor = Colors.blue;
      } else if (statusCode >= 400) {
        statusColor = Colors.red;
      }
    } else if (hasError) {
      statusColor = Colors.red;
    }

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
                      statusCode != null ? '$statusCode' : 'Error',
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
                      method,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    duration,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timestamp,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                url,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Error: ${log['error']}',
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

  void _showLogDetails(dynamic log) {
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
                  title: Text(
                      '${log['method']} ${log['url']?.split('/').last ?? ''}'),
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
                          tabs: const [
                            Tab(text: 'Request'),
                            Tab(text: 'Response'),
                            Tab(text: 'Overview'),
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

  Widget _buildRequestTab(dynamic log) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('URL'),
          _buildCopyableText(log['url'] ?? 'N/A'),
          const SizedBox(height: 16),
          _buildSectionTitle('Method'),
          Text(log['method'] ?? 'N/A'),
          const SizedBox(height: 16),
          _buildSectionTitle('Headers'),
          _buildJsonViewer(log['headers']),
          if (log['requestBody'] != null) ...[
            const SizedBox(height: 16),
            _buildSectionTitle('Body'),
            _buildJsonViewer(log['requestBody']),
          ],
        ],
      ),
    );
  }

  Widget _buildResponseTab(dynamic log) {
    if (log['error'] != null && log['statusCode'] == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Error'),
            Text(
              log['error'],
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
          _buildSectionTitle('Status'),
          Text(
            '${log['statusCode'] ?? 'N/A'}',
            style: TextStyle(
              color: log['statusCode'] != null && log['statusCode'] >= 400
                  ? Colors.red
                  : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('Body'),
          _buildJsonViewer(log['responseBody']),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(dynamic log) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Time'),
          Text(log['timestamp'] != null
              ? DateTime.parse(log['timestamp']).toString()
              : 'N/A'),
          const SizedBox(height: 16),
          _buildSectionTitle('Duration'),
          Text('${log['duration'] ?? 'N/A'} ms'),
          const SizedBox(height: 16),
          _buildSectionTitle('Method'),
          Text(log['method'] ?? 'N/A'),
          const SizedBox(height: 16),
          _buildSectionTitle('URL'),
          _buildCopyableText(log['url'] ?? 'N/A'),
          const SizedBox(height: 16),
          _buildSectionTitle('Status'),
          Text(
            log['statusCode'] != null ? '${log['statusCode']}' : 'Error',
            style: TextStyle(
              color: log['statusCode'] == null ||
                      (log['statusCode'] != null && log['statusCode'] >= 400)
                  ? Colors.red
                  : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('Gate ID'),
          Text(log['gateId'] != null && log['gateId'].isNotEmpty
              ? log['gateId']
              : 'Not specified'),
          const SizedBox(height: 16),
          _buildSectionTitle('Environment'),
          Text(log['environment'] != null && log['environment'].isNotEmpty
              ? log['environment']
              : 'Not specified'),
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
        // Copy to clipboard functionality would go here
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
      return const Text('No content');
    }

    try {
      dynamic jsonData;
      if (content is String) {
        try {
          jsonData = jsonDecode(content);
        } catch (e) {
          return Text(content);
        }
      } else {
        jsonData = content;
      }

      final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonData);
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          prettyJson,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      );
    } catch (e) {
      return Text(content.toString());
    }
  }
}
