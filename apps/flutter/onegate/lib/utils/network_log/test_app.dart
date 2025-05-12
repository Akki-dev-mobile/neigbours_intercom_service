import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/network_log.dart';
import 'test_network_log_capture.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Register the NetworkLog adapter
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(NetworkLogAdapter());
  }
  
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Log Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TestNetworkLogCapture(),
    );
  }
}
