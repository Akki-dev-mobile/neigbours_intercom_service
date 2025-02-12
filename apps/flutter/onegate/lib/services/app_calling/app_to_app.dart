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
      'reconnection': true, // ✅ Enable auto-reconnection
      'reconnectionAttempts': 10, // ✅ Try reconnecting 10 times
      'reconnectionDelay': 5000, // ✅ Wait 5 seconds before retrying
    });

    socket!.onConnect((_) {
      print('✅ Connected to WebSocket server');
      socket!.emit('joinRoom', {'companyId': companyId, 'clientName': appId});
    });

    socket!.onDisconnect((_) {
      print('❌ Disconnected from WebSocket');
      reconnectSocket(); // 🔄 Attempt to reconnect
    });

    socket!.onConnectError((error) => print('⚠️ Connection Error: $error'));
    socket!.onError((error) => print('🚨 WebSocket Error: $error'));

    socket!.connect();
  }

// 🔄 Auto-reconnect on disconnect
  void reconnectSocket() {
    print('🔄 Attempting to reconnect...');
    Future.delayed(Duration(seconds: 5), () {
      if (socket == null || !socket!.connected) {
        initSocket('8191', 'oneapp'); // Reinitialize connection
      }
    });
  }

  void _listenToEvent(String eventName) {
    socket?.on(eventName, (data) {
      print('📩 Received Event: $eventName, Data: $data');
      _messageStreamController.add({'event': eventName, 'data': data});
    });
  }

  void disconnect() {
    socket?.disconnect();
    socket?.dispose();
    socket = null;
    print('🚪 WebSocket disconnected');
  }
}
