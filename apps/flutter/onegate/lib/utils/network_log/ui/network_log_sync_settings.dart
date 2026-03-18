import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/utils/network_log/network_log_manager.dart';
import 'package:flutter_onegate/utils/network_log/services/network_log_background_service.dart';
import 'package:flutter_onegate/utils/network_log/services/network_log_sync_service.dart';

class NetworkLogSyncSettings extends StatefulWidget {
  const NetworkLogSyncSettings({Key? key}) : super(key: key);

  @override
  State<NetworkLogSyncSettings> createState() => _NetworkLogSyncSettingsState();
}

class _NetworkLogSyncSettingsState extends State<NetworkLogSyncSettings> {
  final NetworkLogManager _logManager = NetworkLogManager();
  final TextEditingController _gateIdController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController();
  
  bool _syncEnabled = true;
  bool _backgroundSyncEnabled = true;
  bool _isSyncing = false;
  String _syncStatus = '';
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final syncService = _logManager.syncService;
    final backgroundService = _logManager.backgroundService;
    
    setState(() {
      _gateIdController.text = syncService.gateId;
      _serverUrlController.text = syncService.serverUrl;
      _syncEnabled = syncService.syncEnabled;
      _backgroundSyncEnabled = backgroundService.backgroundSyncEnabled;
    });
  }
  
  Future<void> _saveSettings() async {
    final syncService = _logManager.syncService;
    final backgroundService = _logManager.backgroundService;
    
    await syncService.saveSettings(
      gateId: _gateIdController.text,
      syncEnabled: _syncEnabled,
      serverUrl: _serverUrlController.text,
    );
    
    await backgroundService.saveSettings(
      backgroundSyncEnabled: _backgroundSyncEnabled,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }
  
  Future<void> _triggerManualSync() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = 'Syncing...';
    });
    
    final success = await _logManager.triggerManualSync();
    
    setState(() {
      _isSyncing = false;
      _syncStatus = success ? 'Sync completed successfully' : 'Sync failed';
    });
    
    // Clear status after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _syncStatus = '';
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Log Sync Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gate Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _gateIdController,
              decoration: const InputDecoration(
                labelText: 'Gate ID',
                hintText: 'e.g., MAIN_GATE, TOWER_A_GATE',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Server Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://example.com/logs',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Enable Log Syncing'),
              subtitle: const Text('Allow logs to be synced to the server'),
              value: _syncEnabled,
              onChanged: (value) {
                setState(() {
                  _syncEnabled = value;
                });
              },
            ),
            
            SwitchListTile(
              title: const Text('Enable Background Sync'),
              subtitle: const Text('Sync logs every 2 minutes in the background'),
              value: _backgroundSyncEnabled,
              onChanged: (value) {
                setState(() {
                  _backgroundSyncEnabled = value;
                });
              },
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Manual Sync',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isSyncing ? null : _triggerManualSync,
                  child: _isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: DashboardLoaderIcon(strokeWidth: 2),
                        )
                      : const Text('Sync Now'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _syncStatus,
                    style: TextStyle(
                      color: _syncStatus.contains('failed')
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSettings,
                child: const Text('Save Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _gateIdController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }
}
