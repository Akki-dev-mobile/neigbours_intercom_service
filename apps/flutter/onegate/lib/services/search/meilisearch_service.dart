import 'dart:developer' as dev;
import 'package:meilisearch/meilisearch.dart';
import 'package:flutter_onegate/domain/entities/society/member.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';

/// Service for managing Meilisearch operations
class MeilisearchService {
  static const String _defaultHost = 'http://localhost:7700';
  static const String _residentsIndex = 'residents';
  static const String _visitorsIndex = 'visitors';

  late MeiliSearchClient _client;
  late MeiliSearchIndex _residentsIndexInstance;
  late MeiliSearchIndex _visitorsIndexInstance;

  static final MeilisearchService _instance = MeilisearchService._internal();
  factory MeilisearchService() => _instance;
  MeilisearchService._internal();

  /// Initialize Meilisearch client and indexes
  Future<bool> initialize({String? host, String? apiKey}) async {
    try {
      final gateStorage = GateStorage();
      final meilisearchHost =
          host ?? await gateStorage.getMeilisearchHost() ?? _defaultHost;
      final meilisearchApiKey =
          apiKey ?? await gateStorage.getMeilisearchApiKey();

      _client = MeiliSearchClient(
        meilisearchHost,
        meilisearchApiKey,
      );

      // Initialize indexes
      await _initializeIndexes();

      dev.log('MeilisearchService initialized successfully');
      return true;
    } catch (e) {
      dev.log('Error initializing MeilisearchService: $e');
      return false;
    }
  }

  /// Initialize search indexes with proper settings
  Future<void> _initializeIndexes() async {
    try {
      // Create residents index
      _residentsIndexInstance = _client.index(_residentsIndex);
      await _residentsIndexInstance.updateSearchableAttributes([
        'memberName',
        'memberMobileNumber',
        'memberEmailId',
        'unitFlatNumber',
        'socBuildingName',
        'buildingUnit'
      ]);
      await _residentsIndexInstance.updateFilterableAttributes(
          ['socBuildingName', 'memberStatus', 'approved', 'fkUnitId']);
      await _residentsIndexInstance.updateSortableAttributes(
          ['memberName', 'unitFlatNumber', 'memberEffectiveDate']);

      // Create visitors index
      _visitorsIndexInstance = _client.index(_visitorsIndex);
      await _visitorsIndexInstance.updateSearchableAttributes(
          ['name', 'mobile', 'lastVisitDate', 'visitCount']);
      await _visitorsIndexInstance
          .updateFilterableAttributes(['isStaff', 'lastVisitDate']);
      await _visitorsIndexInstance
          .updateSortableAttributes(['name', 'lastVisitDate', 'visitCount']);

      dev.log('Search indexes initialized successfully');
    } catch (e) {
      dev.log('Error initializing search indexes: $e');
      rethrow;
    }
  }

  /// Index residents data
  Future<bool> indexResidents(List<Member> residents) async {
    try {
      final documents = residents
          .map((resident) => {
                'id': resident.id?.toString() ?? '',
                'memberId': resident.memberId?.toString() ?? '',
                'memberName': resident.memberName?.toString() ?? '',
                'memberMobileNumber':
                    resident.memberMobileNumber?.toString() ?? '',
                'memberEmailId': resident.memberEmailId?.toString() ?? '',
                'unitFlatNumber': resident.unitFlatNumber?.toString() ?? '',
                'socBuildingName': resident.socBuildingName?.toString() ?? '',
                'buildingUnit': resident.buildingUnit?.toString() ?? '',
                'memberStatus': resident.memberStatus?.toString() ?? '',
                'approved': resident.approved?.toString() ?? '',
                'fkUnitId': resident.fkUnitId?.toString() ?? '',
                'memberEffectiveDate':
                    resident.memberEffectiveDate?.toString() ?? '',
                'memberTypeName': resident.memberTypeName?.toString() ?? '',
              })
          .toList();

      await _residentsIndexInstance.addDocuments(documents);
      dev.log('Indexed ${documents.length} residents');
      return true;
    } catch (e) {
      dev.log('Error indexing residents: $e');
      return false;
    }
  }

  /// Index visitors data
  Future<bool> indexVisitors(List<Visitor> visitors) async {
    try {
      final documents = visitors
          .map((visitor) => {
                'id': visitor.id?.toString() ?? '',
                'name': visitor.name ?? '',
                'mobile': visitor.mobile ?? '',
                'visitor_image': visitor.visitor_image ?? '',
                'isStaff': visitor.isStaff ?? false,
                'lastVisitDate': DateTime.now().toIso8601String(),
                'visitCount':
                    1, // This should be calculated from actual visit logs
              })
          .toList();

      await _visitorsIndexInstance.addDocuments(documents);
      dev.log('Indexed ${documents.length} visitors');
      return true;
    } catch (e) {
      dev.log('Error indexing visitors: $e');
      return false;
    }
  }

  /// Search residents with advanced filters
  Future<List<Map<String, dynamic>>> searchResidents({
    required String query,
    String? building,
    String? memberStatus,
    bool? approved,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final filters = <String>[];

      if (building != null && building.isNotEmpty) {
        filters.add('socBuildingName = "$building"');
      }

      if (memberStatus != null && memberStatus.isNotEmpty) {
        filters.add('memberStatus = "$memberStatus"');
      }

      if (approved != null) {
        filters.add('approved = $approved');
      }

      final searchResult = await _residentsIndexInstance.search(query);

      return List<Map<String, dynamic>>.from(searchResult.hits);
    } catch (e) {
      dev.log('Error searching residents: $e');
      return [];
    }
  }

  /// Search visitors with advanced filters
  Future<List<Map<String, dynamic>>> searchVisitors({
    required String query,
    bool? isStaff,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final filters = <String>[];

      if (isStaff != null) {
        filters.add('isStaff = $isStaff');
      }

      if (fromDate != null) {
        filters.add('lastVisitDate >= ${fromDate.millisecondsSinceEpoch}');
      }

      if (toDate != null) {
        filters.add('lastVisitDate <= ${toDate.millisecondsSinceEpoch}');
      }

      final searchResult = await _visitorsIndexInstance.search(query);

      return List<Map<String, dynamic>>.from(searchResult.hits);
    } catch (e) {
      dev.log('Error searching visitors: $e');
      return [];
    }
  }

  /// Get search suggestions
  Future<List<String>> getSearchSuggestions(String query,
      {String index = 'residents'}) async {
    try {
      final targetIndex = index == 'residents'
          ? _residentsIndexInstance
          : _visitorsIndexInstance;

      final searchResult = await targetIndex.search(query);

      return searchResult.hits
          .map((hit) =>
              hit[index == 'residents' ? 'memberName' : 'name']?.toString() ??
              '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      dev.log('Error getting search suggestions: $e');
      return [];
    }
  }

  /// Clear all indexes
  Future<bool> clearAllIndexes() async {
    try {
      await _residentsIndexInstance.deleteAllDocuments();
      await _visitorsIndexInstance.deleteAllDocuments();
      dev.log('All search indexes cleared');
      return true;
    } catch (e) {
      dev.log('Error clearing indexes: $e');
      return false;
    }
  }

  /// Check if Meilisearch is healthy with detailed error reporting
  Future<bool> isHealthy() async {
    try {
      final health = await _client.health();
      dev.log('✅ Meilisearch health check passed: $health');
      return true;
    } catch (e) {
      dev.log('❌ Meilisearch health check failed: $e');

      // Log more detailed error information
      if (e.toString().contains('Connection refused')) {
        dev.log(
            '🔌 Connection Error: Meilisearch server is not running or not accessible');
      } else if (e.toString().contains('timeout')) {
        dev.log('⏱️ Timeout Error: Meilisearch server is not responding');
      } else if (e.toString().contains('401') || e.toString().contains('403')) {
        dev.log(
            '🔐 Authentication Error: Invalid API key or insufficient permissions');
      } else {
        dev.log('🔍 Unknown Error: $e');
      }

      return false;
    }
  }

  /// Get detailed connection status for debugging
  Future<Map<String, dynamic>> getConnectionStatus() async {
    final gateStorage = GateStorage();
    final host = await gateStorage.getMeilisearchHost() ?? _defaultHost;
    final hasApiKey = await gateStorage.getMeilisearchApiKey() != null;

    return {
      'host': host,
      'hasApiKey': hasApiKey,
      'isHealthy': await isHealthy(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
