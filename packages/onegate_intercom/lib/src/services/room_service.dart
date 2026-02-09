import 'dart:convert';

import 'package:onegate_feature_core/onegate_feature_core.dart';

import '../models/room.dart';
import '../models/room_message.dart';
import 'intercom_api_client.dart';

class RoomService {
  RoomService._(this._host, this._client);

  final FeatureHost _host;
  final IntercomApiClient _client;

  static RoomService fromHost(FeatureHost host) {
    return RoomService._(host, IntercomApiClient.fromHost(host));
  }

  Future<List<Room>> getRooms({
    required String companyId,
    String? chatType,
    bool isMember = true,
  }) async {
    final query = <String, dynamic>{
      'company_id': companyId,
      'is_member': isMember,
    };
    if (chatType != null && chatType.trim().isNotEmpty) {
      query['chat_type'] = chatType.trim();
    }

    final res = await _client.get(
      '/rooms/all',
      queryParameters: query,
    );

    final data = _unwrapData(res.data);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((m) => Room.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    return const <Room>[];
  }

  Future<List<RoomMessage>> getMessages({
    required String roomId,
    required String companyId,
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _client.get(
      '/rooms/$roomId/messages',
      queryParameters: {
        'company_id': companyId,
        'limit': limit,
        'offset': offset,
      },
    );

    final data = _unwrapData(res.data);
    if (data == null) return const <RoomMessage>[];

    if (data is List) {
      return data
          .whereType<Map>()
          .map((m) => RoomMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    return const <RoomMessage>[];
  }

  Future<void> sendMessage({
    required String roomId,
    required String content,
  }) async {
    // Prefer WebSocket for sending; REST send endpoint isn't standardized here.
    // Keep this as a placeholder for future migration.
    _host.log('sendMessage called (no REST impl): roomId=$roomId');
  }

  dynamic _unwrapData(dynamic body) {
    if (body == null) return null;
    if (body is Map<String, dynamic>) return body['data'];
    if (body is Map) return body['data'];
    if (body is String) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) return decoded['data'];
        if (decoded is Map) return decoded['data'];
      } catch (_) {
        return null;
      }
    }
    return body;
  }
}
