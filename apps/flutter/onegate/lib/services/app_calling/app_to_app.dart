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

    socket = IO.io('https://stgsocket.cubeone.in/', {
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 3000,
    });

    socket!.onConnect((_) {
      print('✅ Connected to WebSocket server');
      socket!.emit('joinRoom', {'companyId': "8191", 'clientName': appId});
    });

    socket!.onDisconnect((_) {
      print('❌ Disconnected from WebSocket');
      Future.delayed(const Duration(seconds: 2), () {
        if (socket != null && !(socket!.connected)) {
          print('🔄 Attempting reconnection...');
          socket!.connect();
        }
      });
    });

    socket!.onReconnect((_) => print('✅ Successfully reconnected'));
    socket!.onReconnectAttempt((_) => print('🔄 Reconnection attempt...'));
    socket!.onError((data) => print('⚠️ WebSocket Error: $data'));

    // ✅ Listen for newMessage event specifically
    socket!.on('newMessage', (data) {
      print('📩 Received newMessage: $data');
      _messageStreamController.add({'event': 'newMessage', 'data': data});
    });

    // Optional - Debugging listener for all events
    socket!.onAny((event, data) {
      print('🌐 [DEBUG] Received ANY Event: $event, Data: $data');
    });

    socket!.connect();
  }

  void disconnect() {
    if (socket != null) {
      socket!.disconnect();
      socket!.dispose();
      socket = null;
      print('🚪 WebSocket disconnected');
    }
  }
}
