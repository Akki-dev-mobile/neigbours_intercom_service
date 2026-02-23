import 'dart:developer';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../../../core/services/api_service.dart';
import '../../../../core/services/keycloak_service.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/services/society_backend_api_service.dart';
import '../../../../core/utils/profile_data_helper.dart';
import '../../../../core/models/gate_models.dart';
import '../../../../utils/storage/sso_storage.dart';
import '../../../../src/config/intercom_module_config.dart';
import '../models/intercom_contact.dart';
import '../models/gatekeeper.dart';
import '../models/gate_model.dart';
import 'committee_member_cache.dart';

class IntercomService {
  static final IntercomService _instance = IntercomService._internal();
  factory IntercomService() => _instance;
  IntercomService._internal();

  final ApiService _apiService = ApiService.instance;
  final SecureStorageService _storage = SecureStorageService();

  String get _societyBackendBaseUrl =>
      IntercomModule.config.endpoints.societyBackendBaseUrl;

  String get _apiGatewayBaseUrl => IntercomModule.config.endpoints.apiGatewayBaseUrl;

  String get _gateApiBaseUrl => IntercomModule.config.endpoints.gateApiBaseUrl;

  /// Get selected society ID (soc_id) - DEPRECATED: Use selectedFlatProvider instead
  /// This method is kept for backwards compatibility but should not be used in new code
  /// Prefer passing societyId as parameter from selectedFlatProvider
  /// Note: The API parameter is named 'company_id' but it expects the soc_id value
  @Deprecated('Use selectedFlatProvider.getSelectedSocietyId() instead')
  Future<int?> _getSelectedSocietyId() async {
    try {
      // Try to get from selected_society_data (same key used by selectedFlatProvider)
      final societyJson = await _storage.read(key: 'selected_society_data');
      if (societyJson != null) {
        try {
          final societyData = jsonDecode(societyJson) as Map<String, dynamic>;
          final socId = societyData['soc_id'] as int?;
          if (socId != null) {
            log('✅ [IntercomService] Using society ID from selected_society_data: $socId');
            return socId;
          }
        } catch (e) {
          log('⚠️ [IntercomService] Error parsing society data: $e');
        }
      }

      // Fallback to company ID if society ID not available
      final companyId = await _apiService.getSelectedCompanyId();
      if (companyId != null) {
        log('⚠️ [IntercomService] Using company ID as fallback: $companyId');
        return companyId;
      }

      log('⚠️ [IntercomService] No society ID or company ID available');
      return null;
    } catch (e) {
      log('❌ [IntercomService] Error getting selected society ID: $e');
      // Fallback to company ID on error
      try {
        return await _apiService.getSelectedCompanyId();
      } catch (e2) {
        log('❌ [IntercomService] Error getting company ID fallback: $e2');
        return null;
      }
    }
  }

  /// Get headers with Keycloak token for society backend API
  Future<Map<String, String>> _getHeaders() async {
    final token = await KeycloakService.getAccessToken();
    if (token == null) {
      throw Exception('Authentication token not found');
    }
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Access-Token': token,
    };
  }

  /// Get headers with cookies for API gateway (buildings API)
  Future<Map<String, String>> _getApiGatewayHeaders() async {
    final headers = <String, String>{
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Connection': 'keep-alive',
      'Origin': 'https://society.cubeone.in',
      'Referer': 'https://society.cubeone.in/',
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'same-site',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36',
    };

    // Try to get cookies from storage
    try {
      final profile = await SsoStorage.getUserProfile();
      if (profile != null) {
        // Build cookie string
        final cookieParts = <String>[];

        // Add toggle_mode
        cookieParts.add('toggle_mode=society');

        // Add id_token if available
        if (profile['id_token'] != null) {
          cookieParts.add('id_token=${profile['id_token']}');
        } else {
          // Try to get from Keycloak token
          final keycloakToken = await KeycloakService.getAccessToken();
          if (keycloakToken != null) {
            cookieParts.add('id_token=$keycloakToken');
          }
        }

        // Add company_id if available
        int? companyId;
        if (profile['company_id'] != null) {
          companyId = profile['company_id'] is int
              ? profile['company_id'] as int
              : int.tryParse(profile['company_id'].toString());
        } else if (profile['soc_id'] != null) {
          companyId = profile['soc_id'] is int
              ? profile['soc_id'] as int
              : int.tryParse(profile['soc_id'].toString());
        }

        // If still not found, try to get from selected society data
        if (companyId == null) {
          companyId = await _getSelectedSocietyId();
        }

        if (companyId != null) {
          cookieParts.add('company_id=$companyId');
          log('✅ [IntercomService] Added company_id=$companyId to cookies');
        } else {
          log('⚠️ [IntercomService] company_id not found in profile or selected society data');
        }

        // Add company_name if available
        if (profile['company_name'] != null) {
          final encodedName =
              Uri.encodeComponent(profile['company_name'].toString());
          cookieParts.add('company_name=$encodedName');
        }

        // Add x-access-token if available
        if (profile['x_access_token'] != null) {
          cookieParts.add('x-access-token=${profile['x_access_token']}');
        } else {
          // Try to get from Keycloak token
          final keycloakToken = await KeycloakService.getAccessToken();
          if (keycloakToken != null) {
            cookieParts.add('x-access-token=$keycloakToken');
          }
        }

        if (cookieParts.isNotEmpty) {
          headers['Cookie'] = cookieParts.join('; ');
          log('✅ [IntercomService] Cookie header added for API gateway');
        }
      }
    } catch (e) {
      log('⚠️ [IntercomService] Could not get cookies: $e');
    }

    return headers;
  }

  /// Fetch gatekeepers from gates API
  Future<List<IntercomContact>> getGatekeepers({int? companyId}) async {
    try {
      log('🔵 [IntercomService] Fetching gatekeepers...');

      final companyIdToUse = companyId ?? await _getSelectedSocietyId();
      if (companyIdToUse == null) {
        log('⚠️ [IntercomService] Society ID is null, returning empty list');
        return [];
      }

      log('✅ [IntercomService] Using society/company ID: $companyIdToUse');

      // Use society backend API: admin/gates/list
      final headers = await _getHeaders();
      final url = Uri.parse(
          '$_societyBackendBaseUrl/admin/gates/list?company_id=$companyIdToUse');

      log('🔵 [IntercomService] Calling: $url');
      final httpResponse = await http.get(url, headers: headers);

      if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        final decoded = jsonDecode(httpResponse.body);
        final response =
            decoded is Map<String, dynamic> ? decoded : {'data': decoded};

        // Handle different response formats
        List<dynamic> gatesData = [];
        if (response['success'] == true && response['data'] != null) {
          if (response['data'] is List) {
            gatesData = response['data'] as List<dynamic>;
          }
        } else if (response['data'] != null && response['data'] is List) {
          gatesData = response['data'] as List<dynamic>;
        }

        final List<IntercomContact> gatekeepers = [];

        for (final gateJson in gatesData) {
          if (gateJson is! Map<String, dynamic>) continue;

          try {
            // Parse gate using GateModel
            final gate = GateModel.fromJson(gateJson);

            // Add gate as a gatekeeper contact
            if (gate.gateName != null) {
              gatekeepers.add(IntercomContact(
                id: 'gate_${gate.gateId ?? gate.gateName}',
                name: gate.gateName ?? 'Unknown Gate',
                role: gate.gateType ?? 'Security Desk',
                type: IntercomContactType.gatekeeper,
                status: IntercomContactStatus.online, // Default to online
              ));
            }

            // Add gatekeepers from the gate
            if (gate.gatekeepers.isNotEmpty) {
              for (final gatekeeper in gate.gatekeepers) {
                gatekeepers.add(IntercomContact(
                  id: 'gk_${gatekeeper.id ?? gatekeeper.gatekeeperId}',
                  name: gatekeeper.gatekeeperName ?? 'Unknown',
                  role: gatekeeper.designation ?? 'Security Guard',
                  type: IntercomContactType.gatekeeper,
                  status: gatekeeper.isActive == true
                      ? IntercomContactStatus.online
                      : IntercomContactStatus.offline,
                  phoneNumber: gatekeeper.mobile,
                  photoUrl: gatekeeper.profileImage,
                ));
              }
            }
          } catch (e) {
            log('⚠️ [IntercomService] Error parsing gate: $e');
          }
        }

        log('✅ [IntercomService] Fetched ${gatekeepers.length} gatekeepers');
        return gatekeepers;
      } else {
        log('❌ [IntercomService] HTTP error: ${httpResponse.statusCode} - ${httpResponse.body}');
        return [];
      }
    } catch (e, stackTrace) {
      log('❌ [IntercomService] Error fetching gatekeepers: $e');
      log('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Fetch all gates from the unified API endpoint
  /// GET https://gateapi.cubeone.in/api/admin/gates/all?company_id={company_id}
  Future<List<SimpleGateModel>> fetchAllGates({required int companyId}) async {
    try {
      log('🔵 [IntercomService] Fetching all gates from unified API...');

      final headers = await _getHeaders();
      final url =
          Uri.parse('$_gateApiBaseUrl/admin/gates/all?company_id=$companyId');

      log('🔵 [IntercomService] Calling: $url');
      final httpResponse = await http.get(url, headers: headers);

      if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        final decoded = jsonDecode(httpResponse.body) as Map<String, dynamic>;

        if (decoded['success'] == true && decoded['data'] is List) {
          final gates = (decoded['data'] as List)
              .map((item) =>
                  SimpleGateModel.fromJson(item as Map<String, dynamic>))
              .toList();

          log('✅ [IntercomService] Fetched ${gates.length} gates from unified API');
          return gates;
        } else {
          log('⚠️ [IntercomService] No gates data in response or success=false');
          return [];
        }
      } else {
        log('❌ [IntercomService] HTTP error: ${httpResponse.statusCode} - ${httpResponse.body}');
        return [];
      }
    } catch (e, stackTrace) {
      log('❌ [IntercomService] Error fetching gates from unified API: $e');
      log('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Fetch gatekeepers from the unified gates API
  /// Filters by tag == "gate" and status == 1 (active)
  /// Maps to Gatekeeper model for UI compatibility
  Future<List<Gatekeeper>> getGatekeepersList(int companyId) async {
    try {
      log('🔵 [IntercomService] Fetching gatekeepers from unified gates API...');

      // Fetch all gates
      final allGates = await fetchAllGates(companyId: companyId);

      // Filter: tag == "gate" and status == 1 (active)
      final activeGates =
          allGates.where((gate) => gate.isGatekeeper && gate.isActive).toList();

      log('✅ [IntercomService] Found ${activeGates.length} active gatekeeper gates');

      // Map to Gatekeeper model for UI compatibility
      final gatekeepers = activeGates.map((gate) {
        return Gatekeeper(
          userId: gate.gateUserId ??
              gate.id, // Use gate_user_id if available, fallback to gate id
          username: gate.name,
          email: null, // Not available in new API
          status: gate.isActive ? 'active' : 'inactive',
        );
      }).toList();

      log('✅ [IntercomService] Mapped ${gatekeepers.length} gatekeepers');
      return gatekeepers;
    } catch (e, stackTrace) {
      log('❌ [IntercomService] Error fetching gatekeepers: $e');
      log('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Fetch residents from buildings API
  /// Uses the /admin/member/list endpoint which is more efficient than per-building calls
  Future<List<IntercomContact>> getResidents(
      {int? buildingId, int? companyId}) async {
    try {
      log('🔵 [IntercomService] Fetching residents...');

      final companyIdToUse = companyId ?? await _getSelectedSocietyId();
      if (companyIdToUse == null) {
        log('⚠️ [IntercomService] Society ID is null, returning empty list');
        return [];
      }

      log('✅ [IntercomService] Using society/company ID: $companyIdToUse');

      // Use SocietyBackendApiService.getMembers() which uses /admin/member/list
      // This endpoint returns all members with building info already included
      final societyBackendApiService = SocietyBackendApiService.instance;

      // Fetch all members (use a high perPage to get all members in one call)
      // If needed, we can implement pagination later
      log('🔵 [IntercomService] Fetching members from /admin/member/list endpoint');
      final memberResponse = await societyBackendApiService.getMembers(
        page: 1,
        perPage: 1000, // Get a large number to fetch all members
        societyId: companyIdToUse
            .toString(), // FIX: Use companyIdToUse instead of companyId
      );

      log('✅ [IntercomService] Received ${memberResponse.members.length} members from API');
      log('📊 [IntercomService] Total members: ${memberResponse.total}, Has more: ${memberResponse.hasMore}');

      // Log sample member data for debugging
      if (memberResponse.members.isNotEmpty) {
        final sampleMember = memberResponse.members.first;
        log('📝 [IntercomService] Sample member keys: ${sampleMember.keys.take(10).join(", ")}');
        log('📝 [IntercomService] Sample member data: ${sampleMember.toString().substring(0, sampleMember.toString().length > 200 ? 200 : sampleMember.toString().length)}');
      } else {
        log('⚠️ [IntercomService] WARNING: Received empty members list from API!');
      }

      // If there are more pages, fetch them
      if (memberResponse.hasMore && memberResponse.total > 1000) {
        log('⚠️ [IntercomService] More than 1000 members found. Fetching additional pages...');
        // For now, we'll fetch the first 1000. If needed, we can implement full pagination.
        // The user can filter by building to reduce the number of results.
      }

      final List<IntercomContact> residents = [];

      // Map each member to IntercomContact
      int mappedCount = 0;
      int skippedCount = 0;
      for (final member in memberResponse.members) {
        // If buildingId is specified, filter by building
        if (buildingId != null) {
          // Check if member belongs to the specified building
          final memberBuildingId = member['soc_building_id'] ??
              member['building_id'] ??
              member['fk_building_id'];

          if (memberBuildingId == null ||
              memberBuildingId.toString() != buildingId.toString()) {
            continue; // Skip this member if building doesn't match
          }
        }

        // Map the member data to IntercomContact
        // The member data from getMembers() includes building info in soc_building_name
        try {
          final contact = _mapMemberToIntercomContact(
            member,
            IntercomContactType.resident,
          );

          // Only add if contact has a valid name (not "Unknown")
          if (contact.name.isNotEmpty && contact.name != 'Unknown') {
            residents.add(contact);
            mappedCount++;
          } else {
            skippedCount++;
            log('⚠️ [IntercomService] Skipped member with invalid name. Member keys: ${member.keys.take(5).join(", ")}');
          }
        } catch (e) {
          skippedCount++;
          log('❌ [IntercomService] Error mapping member: $e');
          log('   Member data: ${member.toString().substring(0, member.toString().length > 200 ? 200 : member.toString().length)}');
        }
      }

      log('✅ [IntercomService] Mapped ${mappedCount} residents, skipped ${skippedCount}');
      if (buildingId != null) {
        log('🏢 [IntercomService] Filtered to ${residents.length} residents for building $buildingId');
      }
      return residents;
    } catch (e, stackTrace) {
      log('❌ [IntercomService] Error fetching residents: $e');
      log('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Fetch committee members
  /// [companyId] - Optional society ID. If not provided, will try to get from storage (deprecated)
  ///                Preferred: Pass societyId from selectedFlatProvider.getSelectedSocietyId()
  Future<List<IntercomContact>> getCommitteeMembers({int? companyId}) async {
    try {
      log('🔵 [IntercomService] Fetching committee members...');

      final companyIdToUse = companyId ?? await _getSelectedSocietyId();
      if (companyIdToUse == null) {
        log('⚠️ [IntercomService] Society ID is null, returning empty list');
        return [];
      }

      log('✅ [IntercomService] Using society/company ID: $companyIdToUse');

      final headers = await _getHeaders();
      final List<IntercomContact> allCommitteeMembers = [];

      // Step 1: Fetch committees list
      // Note: Using per_page=20 to match current behavior (TabConstants.kCommitteesPerPage)
      // This preserves backward compatibility with existing pagination limits
      final committeesUrl = Uri.parse(
          '$_apiGatewayBaseUrl/admin/committees/list?company_id=$companyIdToUse&page=1&per_page=20');
      log('🔵 [IntercomService] Fetching committees from: $committeesUrl');

      final committeesResponse =
          await http.get(committeesUrl, headers: headers);

      if (committeesResponse.statusCode >= 200 &&
          committeesResponse.statusCode < 300) {
        final committeesDecoded = jsonDecode(committeesResponse.body);
        final committeesData = committeesDecoded is Map<String, dynamic>
            ? committeesDecoded
            : {'data': committeesDecoded};

        // Extract committees list
        List<dynamic> committeesList = [];
        if (committeesData['data'] != null && committeesData['data'] is List) {
          committeesList = committeesData['data'] as List<dynamic>;
        } else if (committeesData['data'] != null &&
            committeesData['data'] is Map) {
          // If data is paginated, get the list from data.data or data.items
          final data = committeesData['data'] as Map<String, dynamic>;
          if (data['data'] != null && data['data'] is List) {
            committeesList = data['data'] as List<dynamic>;
          } else if (data['items'] != null && data['items'] is List) {
            committeesList = data['items'] as List<dynamic>;
          }
        }

        log('✅ [IntercomService] Found ${committeesList.length} committees');

        // Step 2: Fetch committee members with CONCURRENCY LIMITING and CACHING
        // OPTIMIZATION: Limit to 4 concurrent requests to prevent server overload and timeouts
        // This replaces the "26 parallel requests" pattern that caused timeouts
        const int maxConcurrentRequests = 4;
        final cache = CommitteeMemberCache();

        // Prepare committee list with cache check
        final List<Map<String, dynamic>> committeesToFetch = [];
        int cacheHits = 0;

        for (final committee in committeesList) {
          if (committee is! Map<String, dynamic>) continue;

          final committeeId =
              (committee['id'] ?? committee['committee_id'])?.toString();
          if (committeeId == null) continue;

          // Check cache first
          final cachedMembers =
              cache.getCachedMembers(committeeId, companyIdToUse);
          if (cachedMembers != null) {
            // Cache hit - use cached data
            allCommitteeMembers.addAll(cachedMembers);
            cacheHits++;
            log('✅ [IntercomService] Using cached members for committee $committeeId (${cachedMembers.length} members)');
          } else {
            // Cache miss - add to fetch queue
            committeesToFetch.add({
              'id': committeeId,
              'committee': committee,
            });
          }
        }

        log('📊 [IntercomService] Cache stats: ${cacheHits} hits, ${committeesToFetch.length} to fetch');

        // Fetch remaining committees with concurrency limiting
        if (committeesToFetch.isNotEmpty) {
          log('🚀 [IntercomService] Fetching members for ${committeesToFetch.length} committees with concurrency limit ($maxConcurrentRequests)...');

          // Process in batches with concurrency limit
          for (int i = 0;
              i < committeesToFetch.length;
              i += maxConcurrentRequests) {
            final batch =
                committeesToFetch.skip(i).take(maxConcurrentRequests).toList();
            final batchFutures = <Future<void>>[];

            for (final item in batch) {
              final committeeId = item['id'] as String;
              final committee = item['committee'] as Map<String, dynamic>;

              // Skip if request already in-flight
              if (cache.isRequestInFlight(committeeId)) {
                log('⏸️ [IntercomService] Request already in-flight for committee $committeeId, skipping');
                continue;
              }

              // Mark as in-flight
              cache.markRequestInFlight(committeeId);

              // Create future for this committee
              batchFutures.add(
                _fetchCommitteeMembersParallel(
                  committeeId: committeeId,
                  committee: committee,
                  companyId: companyIdToUse,
                  headers: headers,
                ).then((members) {
                  // Cache the result
                  cache.cacheMembers(committeeId, members, companyIdToUse);
                  allCommitteeMembers.addAll(members);
                  cache.markRequestComplete(committeeId);
                  log('✅ [IntercomService] Fetched ${members.length} members for committee $committeeId');
                }).catchError((e) {
                  cache.markRequestComplete(committeeId);
                  log('⚠️ [IntercomService] Error fetching members for committee $committeeId: $e');
                  // Return empty list on error (already handled in _fetchCommitteeMembersParallel)
                }),
              );
            }

            // Wait for batch to complete before starting next batch
            await Future.wait(batchFutures, eagerError: false);

            log('✅ [IntercomService] Completed batch ${(i ~/ maxConcurrentRequests) + 1}/${(committeesToFetch.length / maxConcurrentRequests).ceil()}');
          }

          log('✅ [IntercomService] Completed concurrency-limited fetch: ${allCommitteeMembers.length} total members');
        }
      } else {
        log('❌ [IntercomService] Failed to fetch committees: ${committeesResponse.statusCode} - ${committeesResponse.body}');
        return [];
      }

      log('✅ [IntercomService] Fetched ${allCommitteeMembers.length} total committee members');
      return allCommitteeMembers;
    } catch (e, stackTrace) {
      log('❌ [IntercomService] Error fetching committee members: $e');
      log('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Fetch lobbies from the unified gates API
  /// Filters by tag == "lobby" and status == 1 (active)
  /// Maps to IntercomContact model for UI compatibility
  Future<List<IntercomContact>> getLobbies({int? companyId}) async {
    try {
      log('🔵 [IntercomService] Fetching lobbies from unified gates API...');

      final companyIdToUse = companyId ?? await _getSelectedSocietyId();
      if (companyIdToUse == null) {
        log('⚠️ [IntercomService] Society ID is null, returning empty list');
        return [];
      }

      log('✅ [IntercomService] Using society/company ID: $companyIdToUse');

      // Fetch all gates
      final allGates = await fetchAllGates(companyId: companyIdToUse);

      // Filter: tag == "lobby" and status == 1 (active)
      final activeLobbies =
          allGates.where((gate) => gate.isLobby && gate.isActive).toList();

      log('✅ [IntercomService] Found ${activeLobbies.length} active lobbies');

      // Map to IntercomContact model for UI compatibility
      final lobbies = activeLobbies.map((gate) {
        return IntercomContact(
          id: 'lobby_${gate.id}',
          name: gate.name,
          role: gate.type, // Use gate_type as role (in/out/both)
          type: IntercomContactType.lobby,
          status: gate.isActive
              ? IntercomContactStatus.online
              : IntercomContactStatus.offline,
        );
      }).toList();

      log('✅ [IntercomService] Mapped ${lobbies.length} lobbies');
      return lobbies;
    } catch (e, stackTrace) {
      log('❌ [IntercomService] Error fetching lobbies: $e');
      log('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Fetch members for a single committee (used for parallel fetching)
  /// This method is extracted to enable parallel execution with Future.wait()
  /// OPTIMIZATION: Returns empty list on error instead of throwing, so failures don't block other requests
  Future<List<IntercomContact>> _fetchCommitteeMembersParallel({
    required dynamic committeeId,
    required Map<String, dynamic> committee,
    required int companyId,
    required Map<String, String> headers,
  }) async {
    final List<IntercomContact> members = [];

    try {
      // Fetch committee members for this committee
      // Note: Using per_page=20 to match current behavior (TabConstants.kCommitteeMembersPerPage)
      final membersUrl = Uri.parse(
          '$_apiGatewayBaseUrl/admin/committees/panel/committeeMembers/$committeeId?company_id=$companyId&page=1&per_page=20');
      log('🔵 [IntercomService] Fetching members for committee $committeeId (parallel)');

      // OPTIMIZATION: Add timeout to prevent hanging on slow/failed APIs
      final membersResponse =
          await http.get(membersUrl, headers: headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log('⚠️ [IntercomService] Timeout fetching members for committee $committeeId (10s limit)');
          throw TimeoutException('Request timeout for committee $committeeId');
        },
      );

      if (membersResponse.statusCode >= 200 &&
          membersResponse.statusCode < 300) {
        final membersDecoded = jsonDecode(membersResponse.body);
        final membersData = membersDecoded is Map<String, dynamic>
            ? membersDecoded
            : {'data': membersDecoded};

        // Extract members list
        // The API returns data as an array: [ [], [members...], {committee_info} ]
        // Members are in data[1] (second element)
        List<dynamic> membersList = [];
        if (membersData['data'] != null && membersData['data'] is List) {
          final dataArray = membersData['data'] as List<dynamic>;
          // Check if data[1] exists and is a list of members
          if (dataArray.length > 1 && dataArray[1] is List) {
            membersList = dataArray[1] as List<dynamic>;
            log('✅ [IntercomService] Found ${membersList.length} members in data[1] for committee $committeeId');
          } else {
            // Fallback: try to use data directly if it's a list of members
            membersList = dataArray;
          }
        } else if (membersData['data'] != null && membersData['data'] is Map) {
          // If data is paginated, get the list from data.data or data.items
          final data = membersData['data'] as Map<String, dynamic>;
          if (data['data'] != null && data['data'] is List) {
            membersList = data['data'] as List<dynamic>;
          } else if (data['items'] != null && data['items'] is List) {
            membersList = data['items'] as List<dynamic>;
          }
        }

        // Map each member to IntercomContact
        for (final member in membersList) {
          if (member is Map<String, dynamic>) {
            // Create a copy of member data with committee name as role if role is missing
            final memberData = Map<String, dynamic>.from(member);
            // Use designation_name if available, otherwise use committee name
            if (memberData['role'] == null) {
              if (memberData['designation_name'] != null) {
                memberData['role'] = memberData['designation_name'].toString();
              } else if (committee['name'] != null) {
                memberData['role'] = committee['name'].toString();
              }
            }
            // Map member_name to name if name is not present
            if (memberData['name'] == null &&
                memberData['member_name'] != null) {
              memberData['name'] = memberData['member_name'];
            }

            final contact = _mapMemberToIntercomContact(
                memberData, IntercomContactType.committee);
            members.add(contact);
          }
        }

        log('✅ [IntercomService] Fetched ${membersList.length} members from committee $committeeId (parallel)');
      } else {
        log('⚠️ [IntercomService] Failed to fetch members for committee $committeeId: ${membersResponse.statusCode}');
      }
    } catch (e) {
      log('⚠️ [IntercomService] Error fetching members for committee $committeeId: $e');
    }

    return members;
  }

  /// Fetch society office contacts
  /// Uses the same committee API as Society Office staff are typically committee members
  Future<List<IntercomContact>> getSocietyOfficeContacts(
      {int? companyId}) async {
    try {
      log('🔵 [IntercomService] Fetching society office contacts...');

      final companyIdToUse = companyId ?? await _getSelectedSocietyId();
      if (companyIdToUse == null) {
        log('⚠️ [IntercomService] Society ID is null, returning empty list');
        return [];
      }

      log('✅ [IntercomService] Using society/company ID: $companyIdToUse');

      final headers = await _getHeaders();
      final List<IntercomContact> allOfficeContacts = [];

      // Step 1: Fetch committees list
      final committeesUrl = Uri.parse(
          '$_apiGatewayBaseUrl/admin/committees/list?company_id=$companyIdToUse&page=1&per_page=20');
      log('🔵 [IntercomService] Fetching committees for office contacts from: $committeesUrl');

      final committeesResponse =
          await http.get(committeesUrl, headers: headers);

      if (committeesResponse.statusCode >= 200 &&
          committeesResponse.statusCode < 300) {
        final committeesDecoded = jsonDecode(committeesResponse.body);
        final committeesData = committeesDecoded is Map<String, dynamic>
            ? committeesDecoded
            : {'data': committeesDecoded};

        // Extract committees list
        List<dynamic> committeesList = [];
        if (committeesData['data'] != null && committeesData['data'] is List) {
          committeesList = committeesData['data'] as List<dynamic>;
        } else if (committeesData['data'] != null &&
            committeesData['data'] is Map) {
          // If data is paginated, get the list from data.data or data.items
          final data = committeesData['data'] as Map<String, dynamic>;
          if (data['data'] != null && data['data'] is List) {
            committeesList = data['data'] as List<dynamic>;
          } else if (data['items'] != null && data['items'] is List) {
            committeesList = data['items'] as List<dynamic>;
          }
        }

        log('✅ [IntercomService] Found ${committeesList.length} committees for office contacts');

        // Step 2: For each committee, fetch its members
        for (final committee in committeesList) {
          if (committee is! Map<String, dynamic>) continue;

          final committeeId = committee['id'] ?? committee['committee_id'];
          if (committeeId == null) continue;

          try {
            // Fetch committee members for this committee
            final membersUrl = Uri.parse(
                '$_apiGatewayBaseUrl/admin/committees/panel/committeeMembers/$committeeId?company_id=$companyIdToUse&page=1&per_page=20');
            log('🔵 [IntercomService] Fetching office members for committee $committeeId');

            final membersResponse =
                await http.get(membersUrl, headers: headers);

            if (membersResponse.statusCode >= 200 &&
                membersResponse.statusCode < 300) {
              final membersDecoded = jsonDecode(membersResponse.body);
              final membersData = membersDecoded is Map<String, dynamic>
                  ? membersDecoded
                  : {'data': membersDecoded};

              // Extract members list
              // The API returns data as an array: [ [], [members...], {committee_info} ]
              // Members are in data[1] (second element)
              List<dynamic> membersList = [];
              if (membersData['data'] != null && membersData['data'] is List) {
                final dataArray = membersData['data'] as List<dynamic>;
                // Check if data[1] exists and is a list of members
                if (dataArray.length > 1 && dataArray[1] is List) {
                  membersList = dataArray[1] as List<dynamic>;
                  log('✅ [IntercomService] Found ${membersList.length} office members in data[1]');
                } else {
                  // Fallback: try to use data directly if it's a list of members
                  membersList = dataArray;
                }
              } else if (membersData['data'] != null &&
                  membersData['data'] is Map) {
                // If data is paginated, get the list from data.data or data.items
                final data = membersData['data'] as Map<String, dynamic>;
                if (data['data'] != null && data['data'] is List) {
                  membersList = data['data'] as List<dynamic>;
                } else if (data['items'] != null && data['items'] is List) {
                  membersList = data['items'] as List<dynamic>;
                }
              }

              // Map each member to IntercomContact with office type
              for (final member in membersList) {
                if (member is Map<String, dynamic>) {
                  // Create a copy of member data with committee name as role if role is missing
                  final memberData = Map<String, dynamic>.from(member);
                  // Use designation_name if available, otherwise use committee name
                  if (memberData['role'] == null) {
                    if (memberData['designation_name'] != null) {
                      memberData['role'] =
                          memberData['designation_name'].toString();
                    } else if (committee['name'] != null) {
                      memberData['role'] = committee['name'].toString();
                    }
                  }
                  // Map member_name to name if name is not present
                  if (memberData['name'] == null &&
                      memberData['member_name'] != null) {
                    memberData['name'] = memberData['member_name'];
                  }

                  final contact = _mapMemberToIntercomContact(
                      memberData, IntercomContactType.office);
                  allOfficeContacts.add(contact);
                }
              }

              log('✅ [IntercomService] Fetched ${membersList.length} office members from committee $committeeId');
            } else {
              log('⚠️ [IntercomService] Failed to fetch office members for committee $committeeId: ${membersResponse.statusCode}');
            }
          } catch (e) {
            log('⚠️ [IntercomService] Error fetching office members for committee $committeeId: $e');
          }
        }
      } else {
        log('❌ [IntercomService] Failed to fetch committees for office contacts: ${committeesResponse.statusCode} - ${committeesResponse.body}');
        return [];
      }

      log('✅ [IntercomService] Fetched ${allOfficeContacts.length} total society office contacts');
      return allOfficeContacts;
    } catch (e, stackTrace) {
      log('❌ [IntercomService] Error fetching society office contacts: $e');
      log('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Map API member data to IntercomContact
  IntercomContact _mapMemberToIntercomContact(
    Map<String, dynamic> member,
    IntercomContactType type,
  ) {
    // Build name from member_first_name and member_last_name (API format)
    // This is the primary way the /admin/member/list API returns names
    String? memberName;
    final firstName = member['member_first_name']?.toString().trim();
    final lastName = member['member_last_name']?.toString().trim();

    if (firstName != null && firstName.isNotEmpty) {
      memberName = lastName != null && lastName.isNotEmpty
          ? '$firstName $lastName'
          : firstName;
    } else if (lastName != null && lastName.isNotEmpty) {
      memberName = lastName;
    }

    // Fallback to other name fields if member_first_name/member_last_name not available
    if (memberName == null || memberName.isEmpty) {
      // Try member_name (might contain format like "Name(Building-Unit)")
      if (member['member_name'] != null) {
        final memberNameStr = member['member_name'].toString();
        // Check if name contains parentheses (format: "Name(Building-Unit)")
        if (memberNameStr.contains('(')) {
          final nameMatch = RegExp(r'^([^(]+)').firstMatch(memberNameStr);
          if (nameMatch != null) {
            memberName = nameMatch.group(1)?.trim();
          } else {
            memberName = memberNameStr;
          }
        } else {
          memberName = memberNameStr;
        }
      }
    }

    // More fallbacks
    if (memberName == null || memberName.isEmpty) {
      memberName = member['name']?.toString().trim();
    }
    if (memberName == null || memberName.isEmpty) {
      memberName = member['full_name']?.toString().trim();
    }
    if (memberName == null || memberName.isEmpty) {
      // Try first_name and last_name (without member_ prefix)
      final firstNameAlt = member['first_name']?.toString().trim();
      final lastNameAlt = member['last_name']?.toString().trim();
      if (firstNameAlt != null && firstNameAlt.isNotEmpty) {
        memberName = lastNameAlt != null && lastNameAlt.isNotEmpty
            ? '$firstNameAlt $lastNameAlt'
            : firstNameAlt;
      } else if (lastNameAlt != null && lastNameAlt.isNotEmpty) {
        memberName = lastNameAlt;
      }
    }
    if (memberName == null || memberName.isEmpty) {
      memberName = member['display_name']?.toString().trim() ??
          member['user_name']?.toString().trim();
    }

    // Final fallback
    if (memberName == null || memberName.isEmpty) {
      memberName = 'Unknown';
      log('⚠️ [IntercomService] Member has no name field. Member data keys: ${member.keys.toList()}');
      // Log first few keys to help debug
      if (member.isNotEmpty) {
        log('   Sample member data: ${member.toString().substring(0, member.toString().length > 200 ? 200 : member.toString().length)}');
      }
    }

    // For chat room IDs, we need the global SSO/Account ID
    // Priority 1: user_account_id (global SSO ID)
    // Priority 2: user_id (global or local)
    // Priority 3: member_id (local society member ID - fallback)
    String? contactId;
    int? numericUserId;

    // Check if user_id is actually null (not just the string "null")
    // This is critical: members without user_id are not OneApp users
    final userIdValue = member['user_id']; // Get raw value, not string
    final userId = userIdValue?.toString();
    final hasUserId = userIdValue != null &&
        userId != null &&
        userId != 'null' &&
        userId.isNotEmpty;

    final userAccountId = member['user_account_id']?.toString() ??
        member['old_gate_user_id']?.toString();
    final memberId = member['member_id']?.toString();
    final id = member['id']?.toString();

    // Check if user_id or user_account_id is UUID format (contains dashes) - HIGH PRIORITY
    if (userId != null && userId.contains('-') && userId.length > 20) {
      contactId = userId;
    } else if (userAccountId != null &&
        userAccountId.contains('-') &&
        userAccountId.length > 20) {
      contactId = userAccountId;
    }

    // Extract numeric user ID for call APIs.
    // Prefer user_id for call routing (device token registration aligns to user_id),
    // but keep contactId priority unchanged for chat/presence identifiers.
    if (userId != null && !userId.contains('-')) {
      numericUserId = int.tryParse(userId);
    } else if (userAccountId != null && !userAccountId.contains('-')) {
      numericUserId = int.tryParse(userAccountId);
    } else if (memberId != null) {
      numericUserId = int.tryParse(memberId);
    } else if (id != null) {
      numericUserId = int.tryParse(id);
    }

    // If no UUID-based contactId was set above, fall back to numeric identifiers
    if (contactId == null) {
      contactId = userAccountId ?? userId ?? memberId ?? id ?? 'unknown';
    }

    // Final fallbacks for contactId (redundant safety)
    contactId ??= userId ?? userAccountId ?? memberId ?? id ?? 'unknown';

    String? photoUrl = member['photo']?.toString().trim() ??
        member['photo_url']?.toString().trim() ??
        member['profile_picture']?.toString().trim() ??
        member['avatar']?.toString().trim() ??
        member['image_avatar_url']?.toString().trim();
    if (photoUrl == null || photoUrl.isEmpty) {
      photoUrl = ProfileDataHelper.buildAvatarUrlFromUserId(member['user_id']);
    }

    final rawPhone = member['phone']?.toString().trim() ??
        member['phone_number']?.toString().trim() ??
        member['mobile']?.toString().trim() ??
        member['mobile_number']?.toString().trim() ??
        member['member_mobile_number']?.toString().trim() ??
        member['contact_number']?.toString().trim();

    final phoneNumber = _sanitizePhoneNumber(rawPhone);

    return IntercomContact(
      id: contactId,
      name: memberName,
      unit: member['unit']?.toString().trim() ??
          member['unit_number']?.toString().trim() ??
          member['flat_number']?.toString().trim() ??
          member['unit_flat_number']?.toString().trim() ??
          member['building_unit']?.toString().trim(),
      building: member['building']?.toString().trim() ??
          member['building_name']?.toString().trim() ??
          member['soc_building_name']?.toString().trim() ??
          member['building_id']?.toString().trim() ??
          member['soc_building_id']?.toString().trim(),
      floor: member['floor']?.toString().trim() ??
          member['floor_number']?.toString().trim() ??
          member['soc_floor_number']?.toString().trim(),
      role: member['role']?.toString().trim() ??
          member['designation']?.toString().trim() ??
          member['position']?.toString().trim() ??
          member['member_type_name']?.toString().trim() ??
          member['member_type']?.toString().trim(),
      type: type,
      status: _mapStatusFromString(member['status']?.toString()),
      phoneNumber: phoneNumber,
      photoUrl: photoUrl,
      numericUserId: numericUserId,
      hasUserId: hasUserId, // Track if user_id is null from API
    );
  }

  String? _sanitizePhoneNumber(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (lower == 'null' || lower == 'na' || lower == 'n/a' || lower == '-') {
      return null;
    }
    return trimmed;
  }

  /// Map status string to IntercomContactStatus enum
  IntercomContactStatus _mapStatusFromString(String? status) {
    if (status == null) return IntercomContactStatus.offline;

    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'online':
      case 'active':
        return IntercomContactStatus.online;
      case 'busy':
      case 'occupied':
        return IntercomContactStatus.busy;
      case 'away':
      case 'inactive':
        return IntercomContactStatus.away;
      case 'offline':
      default:
        return IntercomContactStatus.offline;
    }
  }
}
