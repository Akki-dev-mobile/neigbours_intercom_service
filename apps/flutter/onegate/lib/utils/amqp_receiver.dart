import 'dart:convert';
import 'dart:developer';

import 'package:dart_amqp/dart_amqp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';

class AmqpReceiver {
  final GlobalKey<NavigatorState> navigatorKey;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  final ValueNotifier<bool> _isLoadingNotifier =
      ValueNotifier<bool>(true); // Tracks loading state
  Client? _client;

  AmqpReceiver(this.navigatorKey);

  void startListening() async {
    print('Starting AMQP receiver');

    _client = Client(
      settings: ConnectionSettings(
        host: '192.168.1.145',
        port: 15672,
        authProvider: const PlainAuthenticator('guest', 'guest'),
      ),
    );

    bool isAdmin = _preferenceUtils.getIsAdmin() ?? false;

    try {
      Channel channel = await _client!.channel();
      Exchange exchange = await channel.exchange("logs", ExchangeType.FANOUT);
      Queue queue = await channel.queue(
        isAdmin ? "approval_requests_8191" : "approval_response_8191",
        durable: true,
      );

      await queue.bind(exchange, "");
      Consumer consumer = await queue.consume();

      consumer.listen((AmqpMessage message) {
        String payload = message.payloadAsString;
        print("AMQP [x] Received string: $payload");

        if (!isAdmin &&
            (payload.contains("accepted") || payload.contains("rejected"))) {
          _isLoadingNotifier.value = false; // Stop loading on admin response
        }

        _showBottomSheet(payload, message.properties?.replyTo);
      });
    } catch (e) {
      print('Failed to connect to AMQP RabbitMQ server: $e');
    }
  }

  void stopListening() {
    print('Stopping AMQP receiver');
    _client?.close();
  }

  Future<void> sendMesg(String status, int userId, int societyId) async {
    try {
      Map<String, dynamic> message = {
        "status": status,
        "user_id": userId,
        "company_id": societyId,
      };

      log("Sending message: $message");

      ConnectionSettings settings = ConnectionSettings(
        host: "192.168.1.34",
        authProvider: const PlainAuthenticator("guest", "guest"),
      );
      Client client = Client(settings: settings);

      Channel channel = await client.channel();
      Exchange exchange = await channel.exchange(
        "logs",
        ExchangeType.FANOUT,
        durable: false,
      );
      exchange.publish(
        jsonEncode(message),
        null,
        properties: MessageProperties.persistentMessage()
          ..replyTo = 'approval_requests_8191',
      );

      log("Message sent successfully.");
    } catch (e) {
      log("Error sending message: $e");
    }
  }

  void _showBottomSheet(String message, String? replyTo) {
    bool isAdmin = _preferenceUtils.getIsAdmin() ?? false;

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
                    if (isAdmin) ...[
                      ListTile(
                        title: const Text('Accept'),
                        onTap: () {
                          Navigator.pop(context); // Close the popup
                          sendMesg(
                            "accepted",
                            85134, // Replace with dynamic user ID
                            8191, // Replace with dynamic society ID
                          );
                        },
                      ),
                      ListTile(
                        title: const Text('Reject'),
                        onTap: () {
                          Navigator.pop(context); // Close the popup
                          sendMesg(
                            "rejected",
                            85134,
                            8191,
                          );
                        },
                      ),
                    ] else
                      ValueListenableBuilder<bool>(
                        valueListenable: _isLoadingNotifier,
                        builder: (context, isLoading, child) {
                          // Automatically dismiss the popup when status is received
                          if (!isLoading) {
                            Future.microtask(() => Navigator.pop(context));
                          }
                          return ListTile(
                            title: const Text('Approval Status'),
                            subtitle: Text(
                              isLoading
                                  ? 'Waiting for approval...'
                                  : 'Your request has been ${message.contains('accepted') ? 'accepted' : 'rejected'}.',
                            ),
                            onTap: () {
                              Navigator.pop(context);
                            },
                          );
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
