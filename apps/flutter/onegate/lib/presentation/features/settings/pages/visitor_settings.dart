// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:convert';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final remoteDataSource = RemoteDataSource(
      DioSingleton.instance1, DioSingleton.instance2, DioSingleton.instance3);

  @override
  void initState() {
    super.initState();
    PreferenceUtils.getInstance().then((prefs) {
      setState(() {
        _gateIdToogleValue = prefs.getTooglevalue() ?? false;
        _visitorsAddress = prefs.getTooglevalue() ?? false;
        _membersApproval = prefs.getTooglevalue() ?? false;
        print("Gate toggle Toggle value retrieved: $_gateIdToogleValue");
        print("Gate toggle Toggle value retrieved: $_visitorsAddress");
        print(
            "Gate toggle Toggle value retrieved: $_membersApproval"); // Print statement
      });
    }).catchError((error) {
      print(
          "Gate toggle Error retrieving toggle value: $error"); // Error handling
    });
  }

  List<PurposeCategory>? _purposes; // Local state to store fetched purposes

  void _fetchPurposes() async {
    final fetchedPurposes = await remoteDataSource.fetchPurpose();
    setState(() {
      _purposes = fetchedPurposes;
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

                if (_visitorsPurpose) {
                  _fetchPurposes(); // Fetch purposes once

                  showModalBottomSheet(
                    context: context,
                    builder: (context) {
                      return _purposes == null
                          ? Center(child: CircularProgressIndicator())
                          : _purposes!.isEmpty
                              ? Center(child: Text("No purposes available"))
                              : Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ListView.builder(
                                    itemCount: _purposes!.length,
                                    itemBuilder: (context, index) {
                                      final purpose = _purposes![index];
                                      return ListTile(
                                        leading: purpose.purpose_img.isNotEmpty
                                            ? Image.network(
                                                purpose.purpose_img,
                                                width: 40,
                                                height: 40,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    Icon(Icons.error),
                                              )
                                            : Icon(Icons.image),
                                        title:
                                            Text(purpose.purpose_category_name),
                                        trailing: Checkbox(
                                          value: purpose.isSelected,
                                          onChanged: (isChecked) {
                                            setState(() {
                                              purpose.isSelected =
                                                  isChecked ?? false;
                                            });
                                            print(
                                                "Updated purpose: ${purpose.purpose_category_name}, Selected: ${purpose.isSelected}");
                                            _saveSelectedPurposes(_purposes!);
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                );
                    },
                  );
                }
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

  void _saveSelectedPurposes(List<PurposeCategory> purposes) async {
    try {
      final roh = await SharedPreferences.getInstance();
      final selectedPurposes = purposes
          .where((purpose) => purpose.isSelected) // Filter selected purposes
          .map((purpose) => purpose.toJson())
          .toList();
      await roh.setString(
        'selected_purposes',
        jsonEncode(selectedPurposes),
      );
      print("Saved selected purposes: $selectedPurposes");
    } catch (e) {
      print("Failed to save selected purposes: $e");
    }
  }
}
