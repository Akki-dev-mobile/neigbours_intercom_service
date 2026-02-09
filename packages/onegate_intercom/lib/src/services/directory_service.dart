import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';

class DirectoryContact {
  const DirectoryContact({
    required this.name,
    required this.userId,
    this.phone,
    this.avatarUrl,
  });

  final String name;
  final String userId;
  final String? phone;
  final String? avatarUrl;

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

class DirectoryService {
  DirectoryService._(this._host, this._dio, this._societyBaseUrl);

  final FeatureHost _host;
  final Dio _dio;
  final Uri _societyBaseUrl;

  static DirectoryService fromHost(FeatureHost host) {
    final flags = host.featureConfig().flags;
    final rawSocietyBase = flags['onegate.societyBaseUrl'];
    final societyBase = (rawSocietyBase is String && rawSocietyBase.isNotEmpty)
        ? Uri.parse(rawSocietyBase)
        : host.kongBaseUri();

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    return DirectoryService._(host, dio, societyBase);
  }

  Future<List<DirectoryContact>> fetchResidents({required String companyId}) {
    return _fetchMembers(companyId: companyId);
  }

  Future<List<DirectoryContact>> fetchCommittee({required String companyId}) {
    // TODO: if API supports committee filtering, implement it.
    // For now, reuse residents list.
    return _fetchMembers(companyId: companyId);
  }

  Future<List<DirectoryContact>> _fetchMembers({
    required String companyId,
  }) async {
    final token = (await _host.authSession()).accessToken;

    final uri = _societyBaseUrl.replace(
      path: _joinPath(_societyBaseUrl.path, '/v2/admin/member/list'),
      queryParameters: {'company_id': companyId},
    );

    final res = await _dio.getUri(
      uri,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );

    final body = res.data;
    final decoded = (body is String)
        ? (jsonDecode(body) as Map<String, dynamic>)
        : (body as Map<String, dynamic>);

    final data = decoded['data'];
    if (data is! List) return const [];

    // Endpoint returns units with nested `member_details`.
    final contacts = <DirectoryContact>[];
    for (final unit in data) {
      if (unit is! Map) continue;
      final members = unit['member_details'];
      if (members is! List) continue;
      for (final m in members) {
        if (m is! Map) continue;
        final first = (m['member_first_name'] ?? '').toString();
        final last = (m['member_last_name'] ?? '').toString();
        final name = ('$first $last').trim();
        final phone = m['member_mobile_number']?.toString();
        final id = (m['member_id'] ?? m['user_id'] ?? '').toString();
        if (id.trim().isEmpty) continue;
        contacts.add(
          DirectoryContact(
            name: name.isEmpty ? id : name,
            userId: id,
            phone: phone?.trim().isEmpty == true ? null : phone,
            avatarUrl: m['avatar']?.toString(),
          ),
        );
      }
    }

    return contacts;
  }
}

String _joinPath(String basePath, String nextPath) {
  final base = basePath.endsWith('/')
      ? basePath.substring(0, basePath.length - 1)
      : basePath;
  final next = nextPath.startsWith('/') ? nextPath : '/$nextPath';
  if (base.isEmpty) return next;
  return '$base$next';
}

