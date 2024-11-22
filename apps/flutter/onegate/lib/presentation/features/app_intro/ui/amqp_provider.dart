// import 'package:flutter/material.dart';
// import 'package:flutter_onegate/utils/amqp_receiver.dart';
//
// class AmqpReceiverProvider extends ChangeNotifier {
//   final GlobalKey<NavigatorState> navigatorKey;
//   late AmqpReceiver _amqpReceiver;
//
//   AmqpReceiverProvider(this.navigatorKey) {
//     _amqpReceiver = AmqpReceiver(navigatorKey);
//     startListening();
//   }
//
//   void startListening() {
//     _amqpReceiver.startListening();
//   }
//
//   void stopListening() {
//     _amqpReceiver.stopListening();
//   }
//
//   @override
//   void dispose() {
//     stopListening();
//     super.dispose();
//   }
// }
