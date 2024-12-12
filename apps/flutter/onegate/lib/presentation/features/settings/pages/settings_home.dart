// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:developer';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/domain/entities/gate/gate2.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/app_permissions.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/visitor_settings.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../self_entry/self_home_view.dart';
import 'settings_gate.dart';

class SettingsHome extends StatefulWidget {
  const SettingsHome({super.key});

  @override
  State<SettingsHome> createState() => _SettingsHomeState();
}

class _SettingsHomeState extends State<SettingsHome> {
  String? _cameraValue;
  String? _languageValue;
  String? _visitorApprovalTimeValue;
  String? _dataStorageValue;
  String? selectedGate;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  Gate? selectedGateObj;

  List<String> options = [
    'Gate 1',
    'Gate 2',
    'Gate 3',
    'Gate 4',
  ];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    selectedGateObj = _preferenceUtils.getSelectedGate();
    _preferenceUtils.getTooglevalue();
  }

  void _showCameraSettings(BuildContext context) async {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: Theme.of(context).colorScheme.surface,
              ),
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select an option',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shrinkWrap: true,
                    itemCount: _cameraItems.length,
                    itemBuilder: (context, index) {
                      final item = _cameraItems[index];
                      return RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        fillColor: WidgetStateProperty.all(
                          Colors.red,
                        ),
                        title: Text(
                          item.label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        value: item.value,
                        groupValue: _cameraValue,
                        onChanged: (value) {
                          setState(() {
                            _cameraValue = value!;
                          });
                        },
                      );
                    },
                  ),
                  CustomLargeBtn(
                    text: 'Confirm',
                    onPressed: () {
                      setState(() {
                        _cameraValue = _cameraValue;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: 50.0),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLanguageSettings(BuildContext context) async {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: Theme.of(context).colorScheme.surface,
              ),
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select an option',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shrinkWrap: true,
                    itemCount: _languageItems.length,
                    itemBuilder: (context, index) {
                      final item = _languageItems[index];
                      return RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        fillColor: WidgetStateProperty.all(
                          Colors.red,
                        ),
                        title: Text(
                          item.label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        value: item.value,
                        groupValue: _cameraValue,
                        onChanged: (value) {
                          setState(() {
                            _languageValue = value!;
                          });
                        },
                      );
                    },
                  ),
                  CustomLargeBtn(
                    text: 'Confirm',
                    onPressed: () {
                      setState(() {
                        _languageValue = _languageValue;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: 50.0),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showVisitorApprovalTime(BuildContext context) async {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: Theme.of(context).colorScheme.surface,
              ),
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select an option',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: 16.0),
                  ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shrinkWrap: true,
                    itemCount: _visitorApprovalTimeItems.length,
                    itemBuilder: (context, index) {
                      final item = _visitorApprovalTimeItems[index];
                      return RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        fillColor: WidgetStateProperty.all(
                          Colors.red,
                        ),
                        title: Text(
                          item.label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        value: item.value,
                        groupValue: _visitorApprovalTimeValue,
                        onChanged: (value) {
                          setState(() {
                            _cameraValue = value!;
                          });
                        },
                      );
                    },
                  ),
                  CustomLargeBtn(
                    text: 'Confirm',
                    onPressed: () {
                      setState(() {
                        _visitorApprovalTimeValue = _visitorApprovalTimeValue;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: 50.0),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDataStorage(BuildContext context) async {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: Theme.of(context).colorScheme.surface,
              ),
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select an option',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shrinkWrap: true,
                    itemCount: _dataStorageItems.length,
                    itemBuilder: (context, index) {
                      final item = _dataStorageItems[index];
                      return RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        fillColor: WidgetStateProperty.all(
                          Colors.red,
                        ),
                        title: Text(
                          item.label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        value: item.value,
                        groupValue: _visitorApprovalTimeValue,
                        onChanged: (value) {
                          setState(() {
                            _dataStorageValue = value!;
                          });
                        },
                      );
                    },
                  ),
                  CustomLargeBtn(
                    text: 'Confirm',
                    onPressed: () {
                      setState(() {
                        _dataStorageValue = _dataStorageValue;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: 50.0),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageTitle: "Settings",
      pageBody: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SecondarySettingsTile(
            title: 'Gate Settings',
          ),
          PrimarySettingsTile(
            icon: Ionicons.grid_outline,
            title: 'Gate Settings',
            subtitle:
                'Current Preference: ${selectedGateObj?.gateName ?? "Gate 1"}',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GateSelectionView(),
                ),
              );
            },
          ),
          PrimarySettingsTile(
            icon: Ionicons.person_outline,
            title: 'Visitors and Vehicles Settings',
            subtitle: 'All visitors will be auto approved',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GateSettingView(),
                ),
              );
            },
          ),
          PrimarySettingsTile(
            icon: Ionicons.people_outline,
            title: 'Visitors Settings',
            subtitle: 'Mark mandatory fields for visitors',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VisitorSettingsView(),
                ),
              );
            },
          ),
          PrimarySettingsTile(
            icon: Ionicons.time_outline,
            title: 'Visitor Approval Time',
            subtitle:
                'Current Preference: ${_visitorApprovalTimeValue ?? "100 seconds"}',
            onTap: () {
              _showVisitorApprovalTime(context);
            },
          ),
          PrimarySettingsTile(
            icon: Ionicons.alarm_outline,
            title: 'Configure Duty Alarms',
            subtitle: 'Enable/Disable Duty Alarms',
          ),
          SecondarySettingsTile(
            title: 'Applicaton Settings',
          ),
          PrimarySettingsTile(
            icon: Ionicons.camera_outline,
            title: 'Camera Settings',
            subtitle: "Current Preference: ${_cameraValue ?? "Back Camera"}",
            onTap: () {
              _showCameraSettings(context);
            },
          ),
          PrimarySettingsTile(
            icon: Ionicons.file_tray_full_outline,
            title: 'Data Storage',
            subtitle: 'Current Preference: ${_dataStorageValue ?? "6 Months"}',
            onTap: () {
              _showDataStorage(context);
            },
          ),
          PrimarySettingsTile(
            icon: Ionicons.options_outline,
            title: 'Configure Permissions',
            subtitle: 'All Approved',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AppPermissions(),
                ),
              );
            },
          ),
          PrimarySettingsTile(
            icon: Ionicons.options_outline,
            title: 'Self Entry Settings',
            subtitle: 'Enable/Disable Self Entry',
            onTap: () {
              // Fluttertoast.showToast(
              //   msg: "self tap in, coming soon",
              //   toastLength: Toast.LENGTH_SHORT,
              //   gravity: ToastGravity.CENTER,
              //   timeInSecForIosWeb: 1,
              //   backgroundColor: Colors.black,
              //   textColor: Colors.white,
              //   fontSize: 16.0,
              // );
              _preferenceUtils.setIsSelfTapIn(true);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SelfHomeView(),
                ),
              );
            },
          ),
          PrimarySettingsTile(
            icon: Ionicons.shield_half_outline,
            title: 'Change Password',
            subtitle: 'Change your password',
            onTap: () {
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => OtpView(),
              //   ),
              // );
            },
          ),
          // PrimarySettingsTile(
          //   icon: Ionicons.sunny_outline,
          //   title: 'Change Theme',
          //   subtitle:
          //       'Current Settings: ${themeManager.currentThemeMode == oneTheme.ThemeMode.obsidianTheme ? 'Dark' : 'Light'}',
          //   trailing: Switch(
          //     value: themeManager.currentThemeMode ==
          //         oneTheme.ThemeMode.obsidianTheme,
          //     onChanged: (newValue) {
          //       themeManager.toggleTheme();
          //     },
          //   ),
          // ),
          PrimarySettingsTile(
            icon: Ionicons.language_outline,
            title: 'Change Language',
            subtitle: 'Current Preference: ${_languageValue ?? "English"}',
            onTap: () {
              _showLanguageSettings(context);
            },
          ),
          PrimarySettingsTile(
              icon: Ionicons.log_out_outline,
              title: 'Logout',
              subtitle: 'Logout from the app',
              onTap: () {
                logout(context);
              }),
        ],
      ),
    );
  }

  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all stored preferences

    log("User logged out. Navigating to login screen.");

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MyAppLogin()),
    );
  }
}

class PrimarySettingsTile extends StatelessWidget {
  const PrimarySettingsTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        size: 22,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        subtitle ?? '',
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(
                    0.6,
                  ),
            ),
      ),
      onTap: onTap,
      trailing: trailing,
    );
  }
}

class MultiSelectItem<T> {
  final String label;
  final T value;
  MultiSelectItem(this.label, this.value);
}

List<MultiSelectItem<String>> _dataStorageItems = [
  MultiSelectItem<String>('1 month', '1'),
  MultiSelectItem<String>('2 months', '2'),
  MultiSelectItem<String>('3 months', '3'),
  MultiSelectItem<String>('4 months', '4'),
  MultiSelectItem<String>('5 months', '5'),
  MultiSelectItem<String>('6 months', '6'),
];

List<MultiSelectItem<String>> _cameraItems = [
  MultiSelectItem<String>('Front Camera', 'front'),
  MultiSelectItem<String>('Back Camera', 'back'),
];
List<MultiSelectItem<String>> _languageItems = [
  MultiSelectItem<String>('English', 'English'),
  MultiSelectItem<String>('Marathi', 'Marathi'),
  MultiSelectItem<String>('Hindi', 'Hindi'),
];
List<MultiSelectItem<String>> _visitorApprovalTimeItems = [
  MultiSelectItem<String>('20 seconds', '20'),
  MultiSelectItem<String>('40 seconds', '40'),
  MultiSelectItem<String>('60 seconds', '60'),
  MultiSelectItem<String>('80 seconds', '80'),
  MultiSelectItem<String>('100 seconds', '100'),
  MultiSelectItem<String>('120 seconds', '120'),
];

class SecondarySettingsTile extends StatelessWidget {
  const SecondarySettingsTile({
    super.key,
    required this.title,
  });
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        vertical: 0,
        horizontal: 10,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
