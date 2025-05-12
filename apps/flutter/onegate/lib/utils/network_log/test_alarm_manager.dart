import 'dart:developer' as dev;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A simple test app to verify that the android_alarm_manager_plus package is working correctly
class TestAlarmManager extends StatefulWidget {
  const TestAlarmManager({Key? key}) : super(key: key);

  @override
  State<TestAlarmManager> createState() => _TestAlarmManagerState();
}

class _TestAlarmManagerState extends State<TestAlarmManager> {
  static const int _alarmId = 12345;
  bool _isAlarmRunning = false;
  String _status = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _initializeAlarmManager();
  }

  Future<void> _initializeAlarmManager() async {
    try {
      final initialized = await AndroidAlarmManager.initialize();
      setState(() {
        _status = initialized ? 'Initialized' : 'Failed to initialize';
      });
    } catch (e) {
      setState(() {
        _status = 'Error initializing: $e';
      });
    }
  }

  Future<void> _startAlarm() async {
    try {
      final success = await AndroidAlarmManager.oneShot(
        const Duration(seconds: 10),
        _alarmId,
        _alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      setState(() {
        _isAlarmRunning = success;
        _status = success ? 'Alarm scheduled' : 'Failed to schedule alarm';
      });
    } catch (e) {
      setState(() {
        _status = 'Error scheduling alarm: $e';
      });
    }
  }

  Future<void> _stopAlarm() async {
    try {
      final success = await AndroidAlarmManager.cancel(_alarmId);
      setState(() {
        _isAlarmRunning = !success;
        _status = success ? 'Alarm cancelled' : 'Failed to cancel alarm';
      });
    } catch (e) {
      setState(() {
        _status = 'Error cancelling alarm: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Alarm Manager'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: $_status',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _startAlarm,
              child: const Text('Start Alarm (10 seconds)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _stopAlarm,
              child: const Text('Stop Alarm'),
            ),
          ],
        ),
      ),
    );
  }

  /// Callback for the alarm
  @pragma('vm:entry-point')
  static Future<void> _alarmCallback() async {
    dev.log('Alarm fired!');
    // This will run in a separate isolate
  }
}
