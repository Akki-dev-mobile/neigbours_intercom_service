// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:ionicons/ionicons.dart';
import 'package:common_widgets/common_widgets.dart';

class GateSettingView extends StatefulWidget {
  const GateSettingView({super.key});

  @override
  State<GateSettingView> createState() => _GateSettingViewState();
}

class _GateSettingViewState extends State<GateSettingView> {
  bool _visitorsIn = true;
  bool _visitorsOut = false;
  bool _vehicleIn = true;
  bool _vehicleOut = false;

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageTitle: 'Gate Settings',
      pageBody: Column(
        children: [
          ListTile(
            title: Text(
              'Visitors Permissions',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          GateSettingListTile(
            switchValue: _visitorsIn,
            onChanged: (value) {
              setState(() {
                _visitorsIn = value;
              });
            },
            title: 'Visitors In',
            subtitle: 'Enable/Disable Gate 1',
            leadingIcon: Ionicons.person_outline,
          ),
          GateSettingListTile(
            switchValue: _visitorsOut,
            onChanged: (value) {
              setState(() {
                _visitorsOut = value;
              });
            },
            title: 'Visitor Out',
            subtitle: 'Enable/Disable Gate 1',
            leadingIcon: Ionicons.person_outline,
          ),
          ListTile(
            title: Text(
              'Vehicle Permissions',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          GateSettingListTile(
            switchValue: _vehicleIn,
            onChanged: (value) {
              setState(() {
                _vehicleIn = value;
              });
            },
            title: 'Vehicle In',
            subtitle: 'Enable/Disable Gate 1',
            leadingIcon: Ionicons.car_outline,
          ),
          GateSettingListTile(
            switchValue: _vehicleOut,
            onChanged: (value) {
              setState(() {
                _vehicleOut = value;
              });
            },
            title: 'Vehicle Out',
            subtitle: 'Enable/Disable Gate 1',
            leadingIcon: Ionicons.car_outline,
          ),
        ],
      ),
    );
  }
}
