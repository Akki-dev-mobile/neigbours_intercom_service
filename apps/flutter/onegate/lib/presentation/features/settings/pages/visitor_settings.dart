import 'dart:convert';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:flutter_onegate/purpose_mapper.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VisitorSettingsView extends StatefulWidget {
  const VisitorSettingsView({super.key});

  @override
  State<VisitorSettingsView> createState() => _VisitorSettingsViewState();
}

class _VisitorSettingsViewState extends State<VisitorSettingsView> {
  bool _visitorsAddress = false;
  bool _visitorsPurpose = false;
  bool _membersApproval = true;
  bool _gateIdToogleValue = false;

  final remoteDataSource = RemoteDataSource(
      DioSingleton.instance1, DioSingleton.instance2, DioSingleton.instance3);

  List<PurposeCategory>? _purposes; // Using PurposeCategory, not mapper.

  @override
  void initState() {
    super.initState();
    _loadToggleValues();
  }

  void _loadToggleValues() {
    PreferenceUtils.getInstance().then((prefs) {
      setState(() {
        _gateIdToogleValue = prefs.getTooglevalue() ?? false;
        _visitorsAddress = prefs.getTooglevalue() ?? false;
        _membersApproval = prefs.getTooglevalue() ?? false;
      });
    }).catchError((error) {
      print("Error retrieving toggle values: $error");
    });
  }

  void _fetchPurposes() async {
    try {
      final fetchedPurposes = await remoteDataSource.fetchPurpose();
      setState(() {
        _purposes = fetchedPurposes;
      });
    } catch (e) {
      print("Failed to fetch purposes: $e");
    }
  }

  void _updatePurposeSelection(int index, bool isChecked) {
    setState(() {
      // Update only the selected state of the specific purpose
      _purposes![index].isSelected = isChecked;
    });

    // Save only the selected purposes
    _saveSelectedPurposes(
      _purposes!.where((purpose) => purpose.isSelected).toList(),
    );
  }

  void _saveSelectedPurposes(List<PurposeCategory> selectedPurposes) async {
    try {
      final roh = await SharedPreferences.getInstance();
      final jsonString =
          jsonEncode(PurposeCategoryMapper.toJsonList(selectedPurposes));
      await roh.setString('selected_purposes', jsonString);
      print("Saved selected purposes: $jsonString");
    } catch (e) {
      print("Failed to save selected purposes: $e");
    }
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
          GateSettingListTile(
            switchValue: _visitorsAddress,
            onChanged: (value) {
              setState(() {
                _visitorsAddress = value;
              });
              _updateToggleValue(value);
            },
            title: "Visitor's Address",
            subtitle: "Set visitor's address as mandatory",
          ),
          GestureDetector(
            onTap: () {
              if (_visitorsPurpose) {
                _fetchPurposes();

                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text("Select Purpose"),
                      content: _purposes == null
                          ? const Center(child: CircularProgressIndicator())
                          : _purposes!.isEmpty
                              ? const Center(
                                  child: Text("No purposes available"))
                              : SizedBox(
                                  width: double.maxFinite,
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
                                            _updatePurposeSelection(
                                                index, isChecked ?? false);
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _saveSelectedPurposes(
                                _purposes!.where((p) => p.isSelected).toList());
                            Navigator.pop(context);
                          },
                          child: Text("Confirm"),
                        ),
                      ],
                    );
                  },
                );
              }
            },
            child: GateSettingListTile(
              switchValue: _visitorsPurpose,
              onChanged: (value) {
                setState(() {
                  _visitorsPurpose = value;

                  if (_visitorsPurpose) {
                    _fetchPurposes();

                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text("Select Purpose"),
                          content: _purposes == null
                              ? const Center(child: CircularProgressIndicator())
                              : _purposes!.isEmpty
                                  ? const Center(
                                      child: Text("No purposes available"))
                                  : SizedBox(
                                      width: double.maxFinite,
                                      child: ListView.builder(
                                        itemCount: _purposes!.length,
                                        itemBuilder: (context, index) {
                                          final purpose = _purposes![index];
                                          return ListTile(
                                            leading:
                                                purpose.purpose_img.isNotEmpty
                                                    ? Image.network(
                                                        purpose.purpose_img,
                                                        width: 40,
                                                        height: 40,
                                                        errorBuilder: (context,
                                                                error,
                                                                stackTrace) =>
                                                            Icon(Icons.error),
                                                      )
                                                    : Icon(Icons.image),
                                            title: Text(
                                                purpose.purpose_category_name),
                                            trailing: Checkbox(
                                              value: purpose.isSelected,
                                              onChanged: (isChecked) {
                                                setState(() {
                                                  _purposes![index].isSelected =
                                                      isChecked ?? false;
                                                });

                                                // Save the updated purposes in the background
                                                Future.microtask(() {
                                                  _saveSelectedPurposes(
                                                    _purposes!
                                                        .where((purpose) =>
                                                            purpose.isSelected)
                                                        .toList(),
                                                  );
                                                });
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _saveSelectedPurposes(_purposes!
                                    .where((p) => p.isSelected)
                                    .toList());
                                Navigator.pop(context);
                              },
                              child: Text("Confirm"),
                            ),
                          ],
                        );
                      },
                    );
                  }
                });
              },
              title: "Visitor's Purpose",
              subtitle: "Set visitor's purpose as mandatory",
            ),
          ),
          GateSettingListTile(
            switchValue: _membersApproval,
            onChanged: (value) {
              setState(() {
                _membersApproval = value;
              });
              _updateToggleValue(value);
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
              _updateToggleValue(value);
            },
            title: "Gate Id",
            subtitle: "Set gate id as mandatory",
          ),
        ],
      ),
    );
  }

  void _updateToggleValue(bool value) {
    PreferenceUtils.getInstance().then((prefs) {
      prefs.setToogleValue(value);
    }).catchError((error) {
      print("Failed to save toggle value: $error");
    });
  }
}
