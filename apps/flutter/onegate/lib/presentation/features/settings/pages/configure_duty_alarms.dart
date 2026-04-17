import 'package:alarm/alarm.dart';
import 'package:alarm/model/volume_settings.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
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
      pageTitle: context.tr('Configure Duty Alarms'),
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
                  ? context.tr('Select Start Time')
                  : context.tr(
                      'Start Time: {time}',
                      params: {'time': startTime!.format(context)},
                    )),
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
                  ? context.tr('Select End Time')
                  : context.tr(
                      'End Time: {time}',
                      params: {'time': endTime!.format(context)},
                    )),
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
                  ? context.tr('Select Interval')
                  : context.tr(
                      'Interval: {minutes} minutes',
                      params: {'minutes': '${interval!.inMinutes}'},
                    )),
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
                  myFluttertoast(
                    msg: context.tr('Values of all fields are required'),
                  );
                }
              },
              child: Text(context.tr('Set Up Alarms')),
            ),
            ElevatedButton(
              style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.red)),
              onPressed: () {
                deleteAllAlarms();
              },
              child: Text(context.tr('Delete All Alarms')),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: log.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Container(
                          color: Colors.red,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(log[index]),
                          ),
                        ),
                        IconButton(
                            onPressed: () {
                              Alarm.stop(allalarmTime[index].hashCode);
                            },
                            icon: Icon(Icons.stop))
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
          title: Text(context.tr('Select Interval')),
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
              child: Text(context.tr('OK')),
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

  List<DateTime> allalarmTime = [];

  void setupAlarms() async {
    await checkAndroidScheduleExactAlarmPermission();
    print("checkAndroidScheduleExactAlarmPermission Done");
    if (startTime == null || endTime == null || interval == null) {
      myFluttertoast(msg: context.tr('Values of all fields are required'));
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
      myFluttertoast(msg: context.tr('End time must be after start time'));
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
          notificationSettings: NotificationSettings(
            title: context.tr('Duty Alarm'),
            body: context.tr('This is a duty alarm'),
            stopButton: context.tr('Stop the alarm'),
            icon: 'notification_icon',
          ),
          volumeSettings:
              VolumeSettings.fade(fadeDuration: Duration(seconds: 3)),
        ),
      );
      allalarmTime.add(alarmTime);

      setState(() {
        log.add(
          context.tr(
            'Alarm set for {time}',
            params: {'time': '${alarmTime.toLocal()}'},
          ),
        );
        print('Alarm set for ${alarmTime.toLocal()}');
      });

      alarmTime = alarmTime.add(interval!);
    }
    myFluttertoast(msg: context.tr('All alarms have been set up'));
  }

  void deleteAllAlarms() async {
    for (DateTime alarmTime in allalarmTime) {
      await Alarm.stop(alarmTime.hashCode);
    }

    setState(() {
      log.clear();
    });
    myFluttertoast(msg: context.tr('All alarms have been deleted'));
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
        Container(
          color: Colors.black,
          child: Slider(
            value: duration.inMinutes.toDouble(),
            min: 1,
            max: 120,
            divisions: 119,
            label: context.tr(
              '{minutes} minutes',
              params: {'minutes': '${duration.inMinutes}'},
            ),
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
