// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:common_widgets/common_widgets.dart';

class VisitorSettingsView extends StatefulWidget {
  const VisitorSettingsView({super.key});

  @override
  State<VisitorSettingsView> createState() => _VisitorSettingsViewState();
}

class _VisitorSettingsViewState extends State<VisitorSettingsView> {
  bool _visitorsName = true;
  bool _visitorsAddress = false;
  bool _visitorsPurpose = false;
  bool _membersApproval = true;

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageTitle: 'Gate Settings',
      pageBody: Column(
        children: [
          GateSettingListTile(
            switchValue: _visitorsName,
            onChanged: (value) {
              setState(() {
                _visitorsName = value;
              });
            },
            title: "Visitor's Name",
            subtitle: "Set visitor's name as mandatory",
          ),
          GateSettingListTile(
            switchValue: _visitorsAddress,
            onChanged: (value) {
              setState(() {
                _visitorsAddress = value;
              });
            },
            title: "Visitor's Address",
            subtitle: "Set visitor's address as mandatory",
          ),
          GateSettingListTile(
            switchValue: _visitorsPurpose,
            onChanged: (value) {
              setState(() {
                _visitorsPurpose = value;
              });
            },
            title: "Visitor's Purpose",
            subtitle: "Set visitor's purpose as mandatory",
          ),
          GateSettingListTile(
            switchValue: _membersApproval,
            onChanged: (value) {
              setState(() {
                _membersApproval = value;
              });
            },
            title: "Member's Approval",
            subtitle: "Set member's approval as mandatory",
          ),
        ],
      ),
    );
  }
}
