import 'dart:io';

import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:alarm/alarm.dart';

class ConfigureDutyAlarms extends StatefulWidget {
  const ConfigureDutyAlarms({super.key});

  @override
  State<ConfigureDutyAlarms> createState() => _ConfigureDutyAlarmsState();
}

class _ConfigureDutyAlarmsState extends State<ConfigureDutyAlarms> {
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  Duration? interval;
  List<String> log = [];

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageTitle: 'Configure Duty Alarms',
      pageBody: Container(
        height: MediaQuery.of(context).size.height,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() {
                    startTime = time;
                  });
                }
              },
              child: Text(startTime == null
                  ? 'Select Start Time'
                  : 'Start Time: ${startTime!.format(context)}'),
            ),
            ElevatedButton(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() {
                    endTime = time;
                  });
                }
              },
              child: Text(endTime == null
                  ? 'Select End Time'
                  : 'End Time: ${endTime!.format(context)}'),
            ),
            ElevatedButton(
              onPressed: () async {
                final duration = await showDurationPicker(
                  context: context,
                  initialTime: const Duration(minutes: 30),
                );
                if (duration != null) {
                  setState(() {
                    interval = duration;
                  });
                }
              },
              child: Text(interval == null
                  ? 'Select Interval'
                  : 'Interval: ${interval!.inMinutes} minutes'),
            ),
            ElevatedButton(
              onPressed: () {
                print(
                    'Start Time: $startTime, End Time: $endTime, Interval: $interval');
                if (startTime != null && endTime != null && interval != null) {
                  setupAlarms();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Values of all fields are required'),
                    ),
                  );
                }
              },
              child: const Text('Set Up Alarms'),
            ),
            ElevatedButton(
              onPressed: () {
                deleteAllAlarms();
              },
              child: const Text('Delete All Alarms'),
            ),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: log.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    tileColor: Colors.red,
                    title: Text(log[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Duration?> showDurationPicker({
    required BuildContext context,
    required Duration initialTime,
  }) async {
    return showDialog<Duration>(
      context: context,
      builder: (context) {
        Duration selectedDuration = initialTime;
        return AlertDialog(
          title: const Text('Select Interval'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DurationPicker(
                duration: selectedDuration,
                onChange: (val) {
                  selectedDuration = val;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(selectedDuration);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void setupAlarms() {
    final now = TimeOfDay.now();
    final start = DateTime(DateTime.now().year, DateTime.now().month,
        DateTime.now().day, startTime!.hour, startTime!.minute);
    final end = DateTime(DateTime.now().year, DateTime.now().month,
        DateTime.now().day, endTime!.hour, endTime!.minute);
    DateTime current = start;

    while (current.isBefore(end)) {
      Alarm.set(
        alarmSettings: AlarmSettings(
          id: current.hashCode,
          dateTime: current,
          assetAudioPath: 'assets/alarm.mp3',
          loopAudio: true,
          vibrate: true,
          fadeDuration: 3.0,
          warningNotificationOnKill: Platform.isIOS,
          notificationSettings: const NotificationSettings(
            title: 'This is the title',
            body: 'This is the body',
            stopButton: 'Stop the alarm',
            icon: 'notification_icon',
          ),
        ),
      );
      current = current.add(interval!);
      setState(() {
        log.add('Alarm set for ${current.toLocal()}');
      });
    }
  }

  void deleteAllAlarms() {
    Alarm.stop(0);
    setState(() {
      log.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All alarms have been deleted'),
      ),
    );
  }
}

class DurationPicker extends StatefulWidget {
  final Duration duration;
  final ValueChanged<Duration> onChange;

  const DurationPicker(
      {required this.duration, required this.onChange, Key? key})
      : super(key: key);

  @override
  _DurationPickerState createState() => _DurationPickerState();
}

class _DurationPickerState extends State<DurationPicker> {
  late Duration duration;

  @override
  void initState() {
    super.initState();
    duration = widget.duration;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Slider(
          value: duration.inMinutes.toDouble(),
          min: 1,
          max: 120,
          divisions: 119,
          label: '${duration.inMinutes} minutes',
          onChanged: (value) {
            setState(() {
              duration = Duration(minutes: value.toInt());
              widget.onChange(duration);
            });
          },
        ),
      ],
    );
  }
}
