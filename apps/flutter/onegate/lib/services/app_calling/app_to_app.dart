import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  IO.Socket? socket;
  final StreamController<Map<String, dynamic>> _messageStreamController =
      StreamController.broadcast(); // Stream for multiple listeners

  Stream<Map<String, dynamic>> get messageStream =>
      _messageStreamController.stream;

  /// Initializes WebSocket connection and starts listening
  void initSocket(String companyId, String appId) {
    if (socket != null && socket!.connected) {
      print('⚡ WebSocket already connected');
      return;
    }

    socket = IO.io('http://stgsocket.cubeone.in/', {
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 2000,
    });

    socket!.onConnect((_) {
      print('✅ Connected to WebSocket server');
      socket!.emit('joinRoom', {'companyId': companyId, 'clientName': appId});
    });

    // ✅ Listen for specific events
    _listenToEvent('message');
    _listenToEvent('notification');
    _listenToEvent('userJoined');

    // ✅ Listen to all events dynamically
    socket!.onAny((event, data) {
      print('🌐 [ALL EVENTS] Event: $event, Data: $data');
      _messageStreamController.add({'event': event, 'data': data});
    });

    socket!.onError((data) => print('⚠️ WebSocket Error: $data'));
    socket!.onDisconnect((_) => print('❌ Disconnected from WebSocket'));

    socket!.connect();
  }

  /// ✅ Generic event listener
  void _listenToEvent(String eventName) {
    socket!.on(eventName, (data) {
      print('📩 [SPECIFIC EVENT] Event: $eventName, Data: $data');
      _messageStreamController.add({'event': eventName, 'data': data});
    });
  }

  /// ✅ Wait for a specific message before proceeding
  Future<void> waitForMessage(String expectedEvent,
      {int timeoutSeconds = 10}) async {
    print(
        "⏳ Waiting for '$expectedEvent' message for $timeoutSeconds seconds...");

    try {
      final Completer<Map<String, dynamic>> messageCompleter = Completer();

      // ✅ Listen for the event
      StreamSubscription<Map<String, dynamic>>? subscription;
      subscription = messageStream.listen((message) {
        if (message['event'] == expectedEvent) {
          print("✅ Message received: $message");
          messageCompleter.complete(message);
        }
      });

      // ✅ Wait for message or timeout
      final result = await messageCompleter.future.timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          print("❌ Timeout: No message received for '$expectedEvent'.");
          return {
            'event': expectedEvent,
            'data': 'Timeout - No message received'
          };
        },
      );

      // ✅ Cancel the subscription after receiving the message
      await subscription.cancel();
      print("📩 Final message received: $result");
    } catch (e) {
      print("❌ Error while waiting for message: $e");
    }
  }

  /// ✅ Disconnect and clean up WebSocket connection
  void disconnect() {
    if (socket != null) {
      socket!.disconnect();
      socket!.dispose();
      socket = null;
      _messageStreamController.close();
      print('🚪 WebSocket disconnected and disposed');
    }
  }
}
