import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  IO.Socket? socket;
  final StreamController<Map<String, dynamic>> _messageStreamController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get messageStream =>
      _messageStreamController.stream;

  void initSocket(String companyId, String appId) {
    if (socket != null && socket!.connected) {
      print('⚡ WebSocket already connected');
      return;
    }

    socket = IO.io('https://stgsocket.cubeone.in', {
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 3000,
    });

    socket!.onConnect((_) {
      print('✅ Connected to WebSocket server');
      socket!.emit('joinRoom', {'companyId': "412", 'clientName': appId});
    });

    socket!.onDisconnect((_) {
      print('❌ Disconnected from WebSocket');
    });

    socket!.onReconnectAttempt((_) => print('🔄 Attempting reconnection...'));
    socket!.onReconnect((_) => print('✅ Reconnected successfully'));

    socket!.onError((error) => print('⚠️ WebSocket Error: $error'));

    // ✅ Generic listener for all events
    socket!.onAny((event, data) {
      print('📩 Received event: $event, data: $data');
      _messageStreamController.add({
        'event': event,
        'data': data,
      });
    });

    socket!.connect();
  }

  void disconnect() {
    socket?.disconnect();
    socket?.dispose();
    socket = null;
    _messageStreamController.close();
    print('🚪 WebSocket disconnected and disposed');
  }
}
