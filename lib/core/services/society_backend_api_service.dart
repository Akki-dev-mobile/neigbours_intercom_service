import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

import '../../src/config/intercom_module_config.dart';
import '../../utils/storage/sso_storage.dart';
import 'keycloak_service.dart';

class BuildingListResponse {
  final List<Map<String, dynamic>> buildings;
  final bool hasMore;
  final int currentPage;
  final int total;

  const BuildingListResponse({
    required this.buildings,
    required this.hasMore,
    required this.currentPage,
    required this.total,
  });
}

class MemberListResponse {
  final List<Map<String, dynamic>> members;
  final bool hasMore;
  final int currentPage;
  final int total;

  const MemberListResponse({
    required this.members,
    required this.hasMore,
    required this.currentPage,
    required this.total,
  });
}

/// Service for making requests to the "society backend" / API gateway endpoints.
///
/// Host apps inject auth + endpoints via `IntercomModule.configure(...)`.
class SocietyBackendApiService {
  static SocietyBackendApiService? _instance;
  static SocietyBackendApiService get instance =>
      _instance ??= SocietyBackendApiService._();

  SocietyBackendApiService._();

  http.Client get _client => IntercomModule.config.httpClient ?? http.Client();

  int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  Future<Map<String, String>> _getHeaders({String? societyId}) async {
    final token = await KeycloakService.getAccessToken();

    final headers = <String, String>{
      'Accept': 'application/json, text/plain, */*',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (token != null && token.isNotEmpty) 'X-Access-Token': token,
    };

    // Best-effort cookie support (some gateways require it).
    try {
      final profile = await SsoStorage.getUserProfile();
      final cookieParts = <String>[];
      cookieParts.add('toggle_mode=society');

      final idToken = profile?['id_token']?.toString() ?? token;
      if (idToken != null && idToken.isNotEmpty) {
        cookieParts.add('id_token=$idToken');
      }

      final companyId = (societyId != null && societyId.isNotEmpty)
          ? societyId
          : profile?['company_id']?.toString() ?? profile?['soc_id']?.toString();
      if (companyId != null && companyId.isNotEmpty) {
        cookieParts.add('company_id=$companyId');
      }

      final xAccessToken = profile?['x_access_token']?.toString() ?? token;
      if (xAccessToken != null && xAccessToken.isNotEmpty) {
        cookieParts.add('x-access-token=$xAccessToken');
      }

      if (cookieParts.isNotEmpty) {
        headers['Cookie'] = cookieParts.join('; ');
      }
    } catch (_) {
      // ignore
    }

    return headers;
  }

  Future<Map<String, dynamic>> get(
    String endpoint, {
    String? societyId,
  }) async {
    final headers = await _getHeaders(societyId: societyId);
    final url = IntercomModule.config.endpoints.apiGateway('/$endpoint');

    final response = await _client.get(url, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('GET failed: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw Exception('Invalid response');
  }

  int _extractPaginationTotal(Map<String, dynamic> response) {
    final directTotal = _tryParseInt(response['total']);
    if (directTotal != null) return directTotal;

    final meta = response['meta'];
    if (meta is Map) {
      final pagination = meta['pagination'];
      if (pagination is Map) {
        final metaTotal = _tryParseInt(pagination['total']);
        if (metaTotal != null) return metaTotal;
      }
    }

    return 0;
  }

  Future<BuildingListResponse> getBuildings({
    int page = 1,
    int perPage = 50,
    required String societyId,
  }) async {
    try {
      final endpoint = 'admin/building/list?page=$page&per_page=$perPage';
      final response = await get(endpoint, societyId: societyId);

      final ok = response['success'] == true || response['status'] == 'success';
      if (!ok) {
        throw Exception(response['error'] ?? response['message'] ?? 'Failed');
      }

      final data = response['data'];
      final list = (data is List)
          ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      final totalFromApi = _extractPaginationTotal(response);
      final total = totalFromApi > 0 ? totalFromApi : list.length;
      final hasMore = totalFromApi > 0
          ? (page * perPage) < totalFromApi
          : list.length >= perPage;

      return BuildingListResponse(
        buildings: list,
        hasMore: hasMore,
        currentPage: page,
        total: total,
      );
    } catch (e) {
      log('❌ [SocietyBackendApiService] getBuildings error: $e',
          name: 'SocietyBackendApiService');
      rethrow;
    }
  }

  Future<MemberListResponse> getMembers({
    int page = 1,
    int perPage = 50,
    required String societyId,
  }) async {
    try {
      final endpoint = 'admin/member/list?page=$page&per_page=$perPage';
      final response = await get(endpoint, societyId: societyId);

      final ok = response['success'] == true || response['status'] == 'success';
      if (!ok) {
        throw Exception(response['error'] ?? response['message'] ?? 'Failed');
      }

      final data = response['data'];
      final unitList = (data is List)
          ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : const <Map<String, dynamic>>[];

      // The /admin/member/list endpoint returns "units" with nested member lists.
      // Common keys observed across deployments:
      // - `rows` (current)
      // - `member_details` (legacy)
      // Flatten to a single list of member maps and enrich with unit context so
      // callers can render unit/building info.
      final flattenedMembers = <Map<String, dynamic>>[];
      for (final unit in unitList) {
        final nested = unit['rows'] ?? unit['member_details'] ?? unit['members'];
        if (nested is! List) continue;

        for (final entry in nested) {
          if (entry is! Map) continue;
          final member = Map<String, dynamic>.from(entry);

          // Ensure unit context exists (prefer unit-level values).
          final unitFlatNumber = unit['unit_flat_number']?.toString();
          if (unitFlatNumber != null && unitFlatNumber.isNotEmpty) {
            member['unit_flat_number'] = unitFlatNumber;
          }

          final buildingUnit = unit['building_unit']?.toString();
          if (buildingUnit != null && buildingUnit.isNotEmpty) {
            member['unit_building_unit'] = buildingUnit;
            // Keep the member-level `building_unit` if present (it is often the
            // member's display string). Still provide a safe fallback for UIs.
            member.putIfAbsent('building_unit', () => buildingUnit);
          }

          final socBuildingName = unit['soc_building_name']?.toString();
          if (socBuildingName != null && socBuildingName.isNotEmpty) {
            member['soc_building_name'] = socBuildingName;
          }

          final fkUnitId = unit['fk_unit_id'];
          if (fkUnitId != null) {
            member['fk_unit_id'] = fkUnitId;
          }

          final unitId = unit['id'];
          if (unitId != null) {
            member['unit_id'] = unitId;
          }

          final disable = unit['disable'];
          if (disable != null) {
            member['unit_disable'] = disable;
          }

          flattenedMembers.add(member);
        }
      }

      final totalFromApi = _extractPaginationTotal(response);
      final total = totalFromApi > 0 ? totalFromApi : unitList.length;
      final hasMore = totalFromApi > 0
          ? (page * perPage) < totalFromApi
          : unitList.length >= perPage;

      return MemberListResponse(
        members: flattenedMembers,
        hasMore: hasMore,
        currentPage: page,
        total: total,
      );
    } catch (e) {
      log('❌ [SocietyBackendApiService] getMembers error: $e',
          name: 'SocietyBackendApiService');
      rethrow;
    }
  }
}
