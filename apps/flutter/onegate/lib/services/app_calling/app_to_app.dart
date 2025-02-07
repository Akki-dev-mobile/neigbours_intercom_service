import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  late IO.Socket socket;

  void initSocket(String companyId, String appId) {
    socket = IO.io('http://192.168.1.200:3000/',
        IO.OptionBuilder().setTransports(['websocket']).build());

    socket.onConnect((_) {
      print('Connected to Socket.IO server');
      print('companyId: $companyId, appId: $appId');

      socket.emit('joinRoom', {'companyId': companyId, 'clientName': appId});
    });

    socket.on('message', (data) {
      print('Received message: $data');
    });

    socket.onError((data) => print('Socket Error: $data'));
    socket.onDisconnect((_) => print('Disconnected from server'));

    socket.connect();
  }

  void sendMessage(String message, String? userId, String? visitorLogId) {
    socket.emit('sendMessage', {
      'user_id': userId,
      'visitor_log_id': visitorLogId,
      'allow_status': message
    });
  }

  void disconnect() {
    socket.disconnect();
  }
}
