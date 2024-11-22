import 'package:dart_amqp/dart_amqp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';

class AmqpReceiver {
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();

  final GlobalKey<NavigatorState> navigatorKey;

  AmqpReceiver(this.navigatorKey);

  void startListening() async {
    print('Starting AMQP receiver');
    if (_preferenceUtils.getIsAdmin() == true) {
      print('AMQP User is an admin');
      Client client = Client(
        settings: ConnectionSettings(
          host: '192.168.1.34',
          authProvider: const PlainAuthenticator('guest', 'guest'),
        ),
      );
      print('Connecting to AMQP RabbitMQ server');

      try {
        Channel channel = await client.channel();
        Exchange exchange = await channel.exchange("logs", ExchangeType.FANOUT);
        Queue queue = await channel.queue(
          "approval_requests_8191",
          durable: true,
        );

        await queue.bind(exchange, ""); // Bind the queue to the exchange
        Consumer consumer = await queue.consume();
        consumer.listen((AmqpMessage message) {
          // Get the payload as a string
          print("AMQP [x] Received string: ${message.payloadAsString}");

          // Or unserialize to json
          print("AMQP [x] Received json: ${message.payloadAsJson}");

          // Or just get the raw data as a Uint8List
          print("AMQP [x] Received raw: ${message.payload}");

          // The message object contains helper methods for
          // replying, ack-ing and rejecting
          // Remove the reply line or handle the absence of the reply-to property
          // message.reply("AMQP world");
          queue.publish(
            mandatory: true,
            immediate: true,
            "Hello, world!",
            properties: MessageProperties()..replyTo = consumer.queue.name,
          );
          print("AMQP [x] replyTo' to ${consumer.queue.name}");
          print(
              "AMQP [x] Sent 'Hello, world!' to ${message.properties!.replyTo}");
          message.ack();
          // message.reply("AMQP world");

          _showBottomSheet(message.payloadAsString);
        });
      } catch (e) {
        print('Failed to connect to AMQP RabbitMQ server: $e');
      }
    } else {
      print('AMQP User is not an admin');
    }
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
                        // Handle accept action
                      },
                    ),
                    ListTile(
                      title: const Text('Reject'),
                      onTap: () {
                        Navigator.pop(context);
                        // Handle reject action
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
