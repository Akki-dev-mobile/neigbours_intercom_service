import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import 'test_alarm_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize AndroidAlarmManager
  await AndroidAlarmManager.initialize();
  
  runApp(const TestAlarmApp());
}

class TestAlarmApp extends StatelessWidget {
  const TestAlarmApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Alarm Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TestAlarmManager(),
    );
  }
}
