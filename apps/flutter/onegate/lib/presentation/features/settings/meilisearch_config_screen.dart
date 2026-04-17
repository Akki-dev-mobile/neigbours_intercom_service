import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/services/search/meilisearch_config_helper.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';

/// Screen for configuring Meilisearch connection settings
class MeilisearchConfigScreen extends StatefulWidget {
  const MeilisearchConfigScreen({Key? key}) : super(key: key);

  @override
  State<MeilisearchConfigScreen> createState() =>
      _MeilisearchConfigScreenState();
}

class _MeilisearchConfigScreenState extends State<MeilisearchConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _apiKeyController = TextEditingController();

  bool _isLoading = false;
  bool _isTestingConnection = false;
  Map<String, dynamic>? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);

    try {
      final gateStorage = GateStorage();
      final host = await gateStorage.getMeilisearchHost();
      final apiKey = await gateStorage.getMeilisearchApiKey();

      setState(() {
        _hostController.text = host ?? 'http://localhost:7700';
        _apiKeyController.text = apiKey ?? '';
      });

      // Get current status
      final status = await MeilisearchConfigHelper.getConfigurationStatus();
      setState(() => _connectionStatus = status);
    } catch (e) {
      debugPrint('Error loading config: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isTestingConnection = true);

    try {
      final result = await MeilisearchConfigHelper.validateConnection(
        host: _hostController.text.trim(),
        apiKey: _apiKeyController.text.trim().isEmpty
            ? null
            : _apiKeyController.text.trim(),
      );

      setState(() => _connectionStatus = result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['success']
                ? context.tr('Connection successful!')
                : context.tr(
                    'Connection failed: {error}',
                    params: {'error': '${result['error']}'},
                  )),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Error testing connection: {error}',
                params: {'error': '$e'},
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isTestingConnection = false);
    }
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final success = await MeilisearchConfigHelper.setCustomConfiguration(
        host: _hostController.text.trim(),
        apiKey: _apiKeyController.text.trim().isEmpty
            ? null
            : _apiKeyController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? context.tr('Configuration saved successfully!')
                : context.tr('Failed to save configuration')),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );

        if (success) {
          Navigator.of(context).pop(true); // Return true to indicate success
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Error saving configuration: {error}',
                params: {'error': '$e'},
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetToDefaults() async {
    setState(() => _isLoading = true);

    try {
      final success = await MeilisearchConfigHelper.resetToDefaults();

      if (success) {
        await _loadCurrentConfig(); // Reload the form
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? context.tr('Reset to defaults successfully!')
                : context.tr('Failed to reset configuration')),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Error resetting configuration: {error}',
                params: {'error': '$e'},
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageTitle: context.tr('Meilisearch Configuration'),
      pageBody: _isLoading
          ? const Center(child: DashboardLoaderIcon())
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigurationForm(),
                  const SizedBox(height: 16),
                  _buildConnectionStatus(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                  const SizedBox(height: 16),
                  _buildHelpSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildConfigurationForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Server Configuration'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hostController,
              decoration: InputDecoration(
                labelText: context.tr('Meilisearch Host URL'),
                hintText: context.tr('http://localhost:7700'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('Host URL is required');
                }
                final uri = Uri.tryParse(value.trim());
                if (uri == null || !uri.hasAbsolutePath) {
                  return context.tr('Please enter a valid URL');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: context.tr('API Key (Optional)'),
                hintText: context.tr('Leave empty for development'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
              obscureText: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    if (_connectionStatus == null) return const SizedBox.shrink();

    final isSuccess = _connectionStatus!['success'] == true;
    final isHealthy =
        _connectionStatus!['connectionStatus']?['isHealthy'] == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('Connection Status'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isSuccess) ...[
              Text(context.tr('✅ Connection successful')),
              Text(
                context.tr(
                  '✅ Server is {status}',
                  params: {
                    'status': context.tr(isHealthy ? 'healthy' : 'unhealthy'),
                  },
                ),
              ),
            ] else ...[
              Text(
                context.tr(
                  '❌ {error}',
                  params: {'error': '${_connectionStatus!['error']}'},
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isTestingConnection ? null : _testConnection,
                icon: _isTestingConnection
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: DashboardLoaderIcon(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_find),
                label: Text(
                  _isTestingConnection
                      ? context.tr('Testing...')
                      : context.tr('Test Connection'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveConfiguration,
                icon: const Icon(Icons.save),
                label: Text(context.tr('Save')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _resetToDefaults,
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('Reset to Defaults')),
          ),
        ),
      ],
    );
  }

  Widget _buildHelpSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Setup Help'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(context.tr('1. Install Meilisearch server on your machine')),
            Text(context.tr('2. Run: ./meilisearch --master-key="your-key"')),
            Text(context.tr('3. Use http://localhost:7700 as host')),
            Text(context.tr('4. Set your master key as API key')),
            const SizedBox(height: 8),
            Text(
              context.tr('For development, you can leave API key empty.'),
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
