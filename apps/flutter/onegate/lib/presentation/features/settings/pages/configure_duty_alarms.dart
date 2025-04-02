import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/volume_settings.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
// import 'package:alarm/alarm.dart';
import 'package:permission_handler/permission_handler.dart';

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
              style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.red)),
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
              style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.red)),
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
              style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.red)),
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
              style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.red)),
              onPressed: () {
                print(
                    'Start Time: $startTime, End Time: $endTime, Interval: $interval');
                if (startTime != null && endTime != null && interval != null) {
                  setupAlarms();
                } else {
                  myFluttertoast(msg: "Values of all fields are required");
                }
              },
              child: const Text('Set Up Alarms'),
            ),
            ElevatedButton(
              style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.red)),
              onPressed: () {
                deleteAllAlarms();
              },
              child: const Text('Delete All Alarms'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: log.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Container(color: Colors.red,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(log[index]),
                          ),
                        ),
                        IconButton(onPressed: (){Alarm.stop(allalarmTime[index].hashCode);}, icon: Icon(Icons.stop))
                      ],
                    ),
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

  Future<void> checkAndroidScheduleExactAlarmPermission() async {
    final status = await Permission.scheduleExactAlarm.status;
    print('Schedule exact alarm permission: $status.');
    if (status.isDenied) {
      print('Requesting schedule exact alarm permission...');
      final res = await Permission.scheduleExactAlarm.request();
      print(
          'Schedule exact alarm permission ${res.isGranted ? '' : 'not'} granted.');
    }
  }
List<DateTime> allalarmTime=[];

  void setupAlarms() async {
    await checkAndroidScheduleExactAlarmPermission();
    print("checkAndroidScheduleExactAlarmPermission Done");
    if (startTime == null || endTime == null || interval == null) {
      myFluttertoast(msg: "Values of all fields are required");
      return;
    }

    final now = DateTime.now();
    final startDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      startTime!.hour,
      startTime!.minute,
    );
    final endDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      endTime!.hour,
      endTime!.minute,
    );

    if (endDateTime.isBefore(startDateTime)) {
      myFluttertoast(msg: "End time must be after start time");
      return;
    }
    DateTime alarmTime = startDateTime.add(interval!);
    print(alarmTime.isBefore(endDateTime));
    while (endDateTime.isAfter(alarmTime)) {
    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: alarmTime.hashCode,
        dateTime: alarmTime,
        assetAudioPath: 'assets/media/audio/alarm.mp3',
        androidFullScreenIntent: true,
        loopAudio: true,
        vibrate: true,
        notificationSettings: const NotificationSettings(
          title: 'Duty Alarm',
          body: 'This is a duty alarm',
          stopButton: 'Stop the alarm',
          icon: 'notification_icon',
        ), volumeSettings:  VolumeSettings.fade(fadeDuration: Duration(seconds: 3)),
      ),
    );
    allalarmTime.add(alarmTime);

    setState(() {
      log.add('Alarm set for ${alarmTime.toLocal()}');
      print('Alarm set for ${alarmTime.toLocal()}');
    });

    alarmTime = alarmTime.add(interval!);
    }
myFluttertoast(msg: "All alarms have been set up");
  }

  void deleteAllAlarms() async{
        final now = DateTime.now();
    final startDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      startTime!.hour,
      startTime!.minute,
    );
    final endDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      endTime!.hour,
      endTime!.minute,
    );
        // Alarm.stop(551035148);

        // DateTime alarmTime = startDateTime.add(interval!);
int len=log.length;
    for (DateTime alarmTime in allalarmTime) {
    await Alarm.stop(alarmTime.hashCode);

    }

    setState(() {
      log.clear();
    });
    myFluttertoast(msg: "All alarms have been deleted");
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
        Container(color: Colors.black,
          child: Slider(
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
        ),
      ],
    );
  }
}
