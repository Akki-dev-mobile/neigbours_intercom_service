// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:ionicons/ionicons.dart';
import 'package:common_widgets/common_widgets.dart';

class AppPermissions extends StatefulWidget {
  const AppPermissions({super.key});

  @override
  State<AppPermissions> createState() => _AppPermissionsState();
}

class _AppPermissionsState extends State<AppPermissions> {
  bool _drawoverotherapps = true;
  bool _dndsettings = false;

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageTitle: 'Gate Settings',
      pageBody: Column(
        children: [
          GateSettingListTile(
            switchValue: _drawoverotherapps,
            onChanged: (value) {
              setState(() {
                _drawoverotherapps = value;
              });
            },
            title: "Allow 'onegate' to draw over other apps",
            subtitle:
                'This permission is needed to show approval screen when an approval request arrives for a visitor',
          ),
          Divider(
            indent: 16,
            endIndent: 16,
          ),
          GateSettingListTile(
            switchValue: _dndsettings,
            onChanged: (value) {
              setState(() {
                _dndsettings = value;
              });
            },
            title: "Allow 'onegate' to escape 'Do Not Disturb' mode",
            subtitle:
                "This permission is needed to ring the emergency alarm even if your device is in DND mode",
          ),
        ],
      ),
    );
  }
}
