import 'dart:developer' as dev;
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/services/search/meilisearch_service.dart';

/// Helper class for Meilisearch configuration and setup
class MeilisearchConfigHelper {
  static const String defaultHost = 'http://localhost:7700';
  static const String defaultApiKey = ''; // Empty for development

  /// Initialize Meilisearch with default configuration if not already set
  static Future<bool> initializeWithDefaults() async {
    try {
      final gateStorage = GateStorage();
      
      // Check if configuration already exists
      final existingHost = await gateStorage.getMeilisearchHost();
      final existingApiKey = await gateStorage.getMeilisearchApiKey();
      
      // Set default configuration if not exists
      if (existingHost == null) {
        await gateStorage.setMeilisearchHost(defaultHost);
        dev.log('🔧 Set default Meilisearch host: $defaultHost');
      }
      
      if (existingApiKey == null) {
        await gateStorage.setMeilisearchApiKey(defaultApiKey);
        dev.log('🔧 Set default Meilisearch API key (empty for development)');
      }
      
      // Initialize the service
      final meilisearchService = MeilisearchService();
      final initialized = await meilisearchService.initialize();
      
      if (initialized) {
        dev.log('✅ Meilisearch initialized successfully with defaults');
        return true;
      } else {
        dev.log('❌ Failed to initialize Meilisearch with defaults');
        return false;
      }
    } catch (e) {
      dev.log('❌ Error initializing Meilisearch with defaults: $e');
      return false;
    }
  }

  /// Set custom Meilisearch configuration
  static Future<bool> setCustomConfiguration({
    required String host,
    String? apiKey,
  }) async {
    try {
      final gateStorage = GateStorage();
      
      await gateStorage.setMeilisearchHost(host);
      if (apiKey != null) {
        await gateStorage.setMeilisearchApiKey(apiKey);
      }
      
      // Test the configuration
      final meilisearchService = MeilisearchService();
      final initialized = await meilisearchService.initialize(
        host: host,
        apiKey: apiKey,
      );
      
      if (initialized) {
        final isHealthy = await meilisearchService.isHealthy();
        if (isHealthy) {
          dev.log('✅ Custom Meilisearch configuration set and verified');
          return true;
        } else {
          dev.log('❌ Custom Meilisearch configuration set but server is not healthy');
          return false;
        }
      } else {
        dev.log('❌ Failed to initialize Meilisearch with custom configuration');
        return false;
      }
    } catch (e) {
      dev.log('❌ Error setting custom Meilisearch configuration: $e');
      return false;
    }
  }

  /// Get current Meilisearch configuration status
  static Future<Map<String, dynamic>> getConfigurationStatus() async {
    try {
      final gateStorage = GateStorage();
      final meilisearchService = MeilisearchService();
      
      final host = await gateStorage.getMeilisearchHost();
      final hasApiKey = await gateStorage.getMeilisearchApiKey() != null;
      final apiKey = await gateStorage.getMeilisearchApiKey();
      
      // Test connection
      bool isConfigured = false;
      bool isHealthy = false;
      String? error;
      
      try {
        if (host != null) {
          await meilisearchService.initialize();
          isConfigured = true;
          isHealthy = await meilisearchService.isHealthy();
        }
      } catch (e) {
        error = e.toString();
      }
      
      return {
        'host': host ?? 'Not configured',
        'hasApiKey': hasApiKey,
        'apiKeyLength': apiKey?.length ?? 0,
        'isConfigured': isConfigured,
        'isHealthy': isHealthy,
        'error': error,
        'defaultHost': defaultHost,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': 'Failed to get configuration status: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Reset Meilisearch configuration to defaults
  static Future<bool> resetToDefaults() async {
    try {
      final gateStorage = GateStorage();
      
      await gateStorage.setMeilisearchHost(defaultHost);
      await gateStorage.setMeilisearchApiKey(defaultApiKey);
      
      dev.log('🔄 Meilisearch configuration reset to defaults');
      
      // Test the reset configuration
      return await initializeWithDefaults();
    } catch (e) {
      dev.log('❌ Error resetting Meilisearch configuration: $e');
      return false;
    }
  }

  /// Validate Meilisearch server connection
  static Future<Map<String, dynamic>> validateConnection({
    String? host,
    String? apiKey,
  }) async {
    try {
      final gateStorage = GateStorage();
      final testHost = host ?? await gateStorage.getMeilisearchHost() ?? defaultHost;
      final testApiKey = apiKey ?? await gateStorage.getMeilisearchApiKey();
      
      final meilisearchService = MeilisearchService();
      
      // Test initialization
      final initialized = await meilisearchService.initialize(
        host: testHost,
        apiKey: testApiKey,
      );
      
      if (!initialized) {
        return {
          'success': false,
          'error': 'Failed to initialize Meilisearch client',
          'host': testHost,
          'hasApiKey': testApiKey != null && testApiKey.isNotEmpty,
        };
      }
      
      // Test health
      final isHealthy = await meilisearchService.isHealthy();
      
      if (!isHealthy) {
        return {
          'success': false,
          'error': 'Meilisearch server is not healthy',
          'host': testHost,
          'hasApiKey': testApiKey != null && testApiKey.isNotEmpty,
        };
      }
      
      // Get connection status
      final connectionStatus = await meilisearchService.getConnectionStatus();
      
      return {
        'success': true,
        'message': 'Meilisearch connection validated successfully',
        'connectionStatus': connectionStatus,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection validation failed: $e',
        'host': host,
        'hasApiKey': apiKey != null && apiKey.isNotEmpty,
      };
    }
  }
}
