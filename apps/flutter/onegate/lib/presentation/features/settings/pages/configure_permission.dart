// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:common_widgets/common_widgets.dart';

class ConfigurePermission extends StatefulWidget {
  const ConfigurePermission({super.key});

  @override
  State<ConfigurePermission> createState() => _ConfigurePermissionState();
}

class _ConfigurePermissionState extends State<ConfigurePermission> {
  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageTitle: 'Configure Permission',
      pageBody: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Card(
              elevation: 0.5,
              child: ListTile(
                leading: Icon(
                  Icons.accessibility,
                  color: Colors.green,
                ),
                title: Text("Allow 'onegate' to draw over other apps"),
                subtitle: Text(
                  "This permission is needed to show the approval screen when an approval request arrives for a visitor.",
                  style: TextStyle(
                    fontWeight: FontWeight.w300,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
            Card(
              elevation: 0.5,
              child: ListTile(
                leading: Icon(
                  Icons.do_not_disturb_on_total_silence_outlined,
                  color: Colors.red,
                ),
                title: Text("Allow 'onegate' to escape 'Do Not Disturb' mode"),
                subtitle: Text(
                  "This permission is needed to ring an emergency alarm even if your device is in DND mode",
                  style: TextStyle(
                    fontWeight: FontWeight.w300,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
