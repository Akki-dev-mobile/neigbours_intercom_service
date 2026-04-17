// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:ionicons/ionicons.dart';

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
      backButtonPressed: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => GateDashboardView(),
          ),
          (route) => false,
        );
      },
      pageTitle: context.tr('Gate Settings'),
      pageBody: Column(
        children: [
          ListTile(
            title: Text(
              context.tr('Visitors Permissions'),
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
            title: context.tr('Visitors In'),
            subtitle: context.tr('Enable/Disable Gate 1'),
            leadingIcon: Ionicons.person_outline,
          ),
          GateSettingListTile(
            switchValue: _visitorsOut,
            onChanged: (value) {
              setState(() {
                _visitorsOut = value;
              });
            },
            title: context.tr('Visitor Out'),
            subtitle: context.tr('Enable/Disable Gate 1'),
            leadingIcon: Ionicons.person_outline,
          ),
          ListTile(
            title: Text(
              context.tr('Vehicle Permissions'),
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
            title: context.tr('Vehicle In'),
            subtitle: context.tr('Enable/Disable Gate 1'),
            leadingIcon: Ionicons.car_outline,
          ),
          GateSettingListTile(
            switchValue: _vehicleOut,
            onChanged: (value) {
              setState(() {
                _vehicleOut = value;
              });
            },
            title: context.tr('Vehicle Out'),
            subtitle: context.tr('Enable/Disable Gate 1'),
            leadingIcon: Ionicons.car_outline,
          ),
        ],
      ),
    );
  }
}
