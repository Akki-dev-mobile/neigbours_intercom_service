import 'package:dart_amqp/dart_amqp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';

class AmqpReceiver {
  final GlobalKey<NavigatorState> navigatorKey;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  Client? _client;

  AmqpReceiver(this.navigatorKey);

  void startListening() async {
    print('Starting AMQP receiver');
    if (_preferenceUtils.getIsAdmin() == true) {
      print('AMQP User is an admin');
      _client = Client(
        settings: ConnectionSettings(
          host: '192.168.1.34',
          authProvider: const PlainAuthenticator('guest', 'guest'),
        ),
      );

      try {
        Channel channel = await _client!.channel();
        Exchange exchange = await channel.exchange("logs", ExchangeType.FANOUT);
        Queue queue = await channel.queue(
          "approval_requests_8191",
          durable: true,
        );

        await queue.bind(exchange, "");
        Consumer consumer = await queue.consume();
        consumer.listen((AmqpMessage message) {
          print("AMQP [x] Received string: ${message.payloadAsString}");
          _showBottomSheet(message.payloadAsString);
        });
      } catch (e) {
        print('Failed to connect to AMQP RabbitMQ server: $e');
      }
    } else {
      print('AMQP User is not an admin');
    }
  }

  void stopListening() {
    print('Stopping AMQP receiver');
    _client?.close();
  }

  void _showBottomSheet(String message) {
    navigatorKey.currentState?.push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (BuildContext context, _, __) {
          return Scaffold(
            backgroundColor: Colors.black54,
            body: Center(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                margin: const EdgeInsets.symmetric(horizontal: 20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      title: const Text('Message Received'),
                      subtitle: Text(message),
                    ),
                    ListTile(
                      title: const Text('Accept'),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      title: const Text('Reject'),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
