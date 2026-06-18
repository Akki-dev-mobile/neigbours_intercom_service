import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants.dart';
import '../services/keycloak_service.dart';

/// WebSocket service for call events from meet-service.
///
/// Listens for call_accepted / call_answered / call_declined / call_rejected / call_ended.
class CallWebSocketService {
  CallWebSocketService._();

  static final CallWebSocketService instance = CallWebSocketService._();

  static const String _logName = 'CallWebSocketService';

  WebSocketChannel? _channel;
  WebSocket? _webSocket;
  StreamSubscription? _subscription;
  bool _isConnecting = false;
  bool _manualDisconnect = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  bool get isConnected =>
      _channel != null && _webSocket?.readyState == WebSocket.open;

  Future<bool> connect({String? accessToken}) async {
    if (isConnected) return true;
    if (_isConnecting) return false;
    try {
      _isConnecting = true;
      _manualDisconnect = false;
      final token = accessToken ?? await KeycloakService.getAccessToken();
      if (token == null || token.isEmpty) {
        log('⚠️ [$_logName] Missing access token - cannot connect');
        _isConnecting = false;
        return false;
      }

      final url = _buildWsUrl(token);
      _webSocket = await WebSocket.connect(url);
      _webSocket?.pingInterval = const Duration(seconds: 20);
      _channel = IOWebSocketChannel(_webSocket!);

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (e, st) {
          log('❌ [$_logName] WebSocket error: $e');
          _teardown();
          _scheduleReconnect();
        },
        onDone: () {
          log('ℹ️ [$_logName] WebSocket closed');
          _teardown();
          _scheduleReconnect();
        },
        cancelOnError: false,
      );

      log('✅ [$_logName] Connected: $url');
      _isConnecting = false;
      _reconnectAttempts = 0;
      return true;
    } catch (e, st) {
      log('❌ [$_logName] Connect failed: $e', error: e, stackTrace: st);
      _teardown();
      _isConnecting = false;
      _scheduleReconnect();
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      _manualDisconnect = true;
      _reconnectTimer?.cancel();
      await _subscription?.cancel();
      await _channel?.sink.close();
      await _webSocket?.close();
    } catch (_) {
      // ignore
    } finally {
      _teardown();
    }
  }

  void _teardown() {
    _subscription = null;
    _channel = null;
    _webSocket = null;
  }

  void _scheduleReconnect() {
    if (_manualDisconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      log('⏸️ [$_logName] Max reconnect attempts reached');
      return;
    }

    _reconnectAttempts++;
    final delaySeconds = _reconnectAttempts * 2;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      log('🔄 [$_logName] Reconnect attempt $_reconnectAttempts');
      await connect();
    });
  }

  void _handleMessage(dynamic data) {
    try {
      if (data is! String || data.isEmpty) return;
      final decoded = jsonDecode(data);
      if (decoded is! Map) return;
      final payload = Map<String, dynamic>.from(decoded);
      final action = payload['action']?.toString();
      if (action == null || action.isEmpty) return;

      switch (action) {
        case 'call_accepted':
        case 'call_answered':
        case 'call_declined':
        case 'call_rejected':
        case 'call_ended':
          _eventController.add(payload);
          break;
        default:
          break;
      }
    } catch (e) {
      log('⚠️ [$_logName] Message parse error: $e');
    }
  }

  String _buildWsUrl(String token) {
    final base = AppConstants.callServiceBaseUrl;
    final uri = Uri.parse(base);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final port = uri.hasPort ? uri.port : (scheme == 'wss' ? 443 : 80);
    final portSuffix = (port == 443 || port == 80) ? '' : ':$port';
    final pathBase = uri.path.isEmpty || uri.path == '/'
        ? ''
        : uri.path.replaceAll(RegExp(r'/$'), '');
    final wsPath = '$pathBase/ws';

    final query = <String>[];
    query.add('token=${Uri.encodeComponent(token)}');
    if (AppConstants.includePackageNameOnCallWebSocket) {
      final packageName = AppConstants.appPackageName;
      if (packageName != null && packageName.trim().isNotEmpty) {
        query.add('package_name=${Uri.encodeComponent(packageName.trim())}');
      }
    }

    return '$scheme://${uri.host}$portSuffix$wsPath?${query.join('&')}';
  }
}
