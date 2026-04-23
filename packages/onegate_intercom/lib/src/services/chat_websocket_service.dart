import 'dart:async';
import 'dart:convert';

import 'package:onegate_feature_core/onegate_feature_core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatWebSocketService {
  ChatWebSocketService._(this._host, this._wsBaseUrl);

  final FeatureHost _host;
  final Uri _wsBaseUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  static ChatWebSocketService fromHost(FeatureHost host) {
    final flags = host.featureConfig().flags;
    final raw = flags['onegate.chatApiBaseUrl'];
    final restBase = (raw is String && raw.trim().isNotEmpty)
        ? Uri.parse(raw.trim())
        : Uri.parse('https://apigw.cubeone.in/chatapp/api/v1');

    final ws = _toWsBase(restBase);
    return ChatWebSocketService._(host, ws);
  }

  Future<void> connect({required String roomId}) async {
    final token = (await _host.authSession()).accessToken;
    final uri = _wsBaseUrl.replace(
      queryParameters: {
        'token': token,
        'room_id': roomId,
      },
    );

    await disconnect();
    _channel = WebSocketChannel.connect(uri);
    _sub = _channel!.stream.listen(
      (event) {
        try {
          final decoded = jsonDecode(event.toString());
          if (decoded is Map<String, dynamic>) {
            _messages.add(decoded);
          } else if (decoded is Map) {
            _messages.add(Map<String, dynamic>.from(
              decoded.map((k, v) => MapEntry(k.toString(), v)),
            ));
          }
        } catch (_) {}
      },
      onError: (e, st) =>
          _host.log('WebSocket error', error: e, stackTrace: st),
      onDone: () => _host.log('WebSocket closed'),
      cancelOnError: false,
    );
  }

  void sendText({required String roomId, required String content}) {
    final c = _channel;
    if (c == null) return;
    c.sink.add(jsonEncode({
      'type': 'message',
      'room_id': roomId,
      'content': content,
      'message_type': 'text',
    }));
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }
}

Uri _toWsBase(Uri restBase) {
  final scheme = restBase.scheme == 'https' ? 'wss' : 'ws';
  // REST is .../api/v1 ; WS is .../api/v1/ws
  final path = restBase.path.endsWith('/')
      ? '${restBase.path}ws'
      : '${restBase.path}/ws';
  return restBase.replace(scheme: scheme, path: path, queryParameters: {});
}
