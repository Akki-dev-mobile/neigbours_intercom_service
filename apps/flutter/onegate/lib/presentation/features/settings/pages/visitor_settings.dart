// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';

class VisitorSettingsView extends StatefulWidget {
  const VisitorSettingsView({super.key});

  @override
  State<VisitorSettingsView> createState() => _VisitorSettingsViewState();
}

class _VisitorSettingsViewState extends State<VisitorSettingsView> {
  // bool _visitorsName = true;
  bool _visitorsAddress = false;
  bool _visitorsPurpose = false;
  bool _membersApproval = true;
  bool _gateIdToogleValue = false;

  @override
  void initState() {
    super.initState();
    PreferenceUtils.getInstance().then((prefs) {
      setState(() {
        _gateIdToogleValue = prefs.getTooglevalue() ?? false;
        _visitorsAddress = prefs.getTooglevalue() ?? false;
        _membersApproval = prefs.getTooglevalue() ?? false;
        print(
            "Gate toggle Toggle value retrieved: $_gateIdToogleValue"); 
            print(
            "Gate toggle Toggle value retrieved: $_visitorsAddress");
            print(
            "Gate toggle Toggle value retrieved: $_membersApproval");// Print statement
      });
    }).catchError((error) {
      print(
          "Gate toggle Error retrieving toggle value: $error"); // Error handling
    });
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      backButtonPressed: () {
        Navigator.pop(context);
      },
      pageTitle: 'Gate Settings',
      pageBody: Column(
        children: [
          // GateSettingListTile(
          //   switchValue: _visitorsName,
          //   onChanged: (value) {
          //     setState(() {
          //       _visitorsName = value;
          //     });
          //   },
          //   title: "Visitor's Name",
          //   subtitle: "Set visitor's name as mandatory",
          // ),
          GateSettingListTile(
            switchValue: _visitorsAddress,
            onChanged: (value) {
              setState(() {
                _visitorsAddress = value;
              });
              print("Gate toggle value $_visitorsAddress");

              PreferenceUtils.getInstance().then((prefs) {
                prefs.setToogleValue(value);
              }).catchError((error) {
                print("Failed to save Gate toggle value: $error");
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
              print("Gate toggle value $_visitorsPurpose");

              PreferenceUtils.getInstance().then((prefs) {
                prefs.setToogleValue(value);
              }).catchError((error) {
                print("Failed to save Gate toggle value: $error");
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
              PreferenceUtils.getInstance().then((prefs) {
                prefs.setToogleValue(value);
              }).catchError((error) {
                print("Failed to save Gate toggle value: $error");
              });
            },
            title: "Member's Approval",
            subtitle: "Set member's approval as mandatory",
          ),

          GateSettingListTile(
            switchValue: _gateIdToogleValue,
            onChanged: (value) {
              setState(() {
                _gateIdToogleValue = value;
              });
              print("Gate toggle value $_gateIdToogleValue");

              PreferenceUtils.getInstance().then((prefs) {
                prefs.setToogleValue(value);
              }).catchError((error) {
                print("Failed to save Gate toggle value: $error");
              });
            },
            title: "Gate Id",
            subtitle: "Set gate id as mandatory",
          ),
        ],
      ),
    );
  }
}
