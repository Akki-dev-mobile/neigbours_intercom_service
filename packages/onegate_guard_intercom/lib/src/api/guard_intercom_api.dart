import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onegate_feature_core/onegate_feature_core.dart';

class GuardIntercomApi {
  GuardIntercomApi._({
    required FeatureHost host,
    required Uri societyBaseUri,
  })  : _host = host,
        _societyBaseUri = societyBaseUri;

  final FeatureHost _host;
  final Uri _societyBaseUri;

  static GuardIntercomApi fromHost(FeatureHost host) {
    final flags = host.featureConfig().flags;

    final societyBase =
        _parseUri(flags['onegate.societyBaseUrl']) ?? host.kongBaseUri();

    return GuardIntercomApi._(
      host: host,
      societyBaseUri: societyBase,
    );
  }

  Future<List<dynamic>> fetchMembers({
    required String companyId,
    String? buildingName,
  }) async {
    final token = (await _host.authSession()).accessToken;

    final queryParams = <String, String>{'company_id': companyId};
    if (buildingName != null && buildingName.trim().isNotEmpty) {
      queryParams['building_name'] = buildingName.trim();
    }

    final uri = _societyBaseUri.replace(
      path: _joinPath(_societyBaseUri.path, '/v2/admin/member/list'),
      queryParameters: queryParams,
    );

    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch members: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected members response');
    }
    final data = decoded['data'];
    if (data is! List) return const <dynamic>[];
    return data;
  }
}

Uri? _parseUri(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return Uri.tryParse(trimmed);
}

String _joinPath(String basePath, String nextPath) {
  final base = basePath.endsWith('/') ? basePath.substring(0, basePath.length - 1) : basePath;
  final next = nextPath.startsWith('/') ? nextPath : '/$nextPath';
  if (base.isEmpty) return next;
  return '$base$next';
}
