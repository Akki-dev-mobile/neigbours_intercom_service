// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:developer';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_kiosk_mode/flutter_kiosk_mode.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/gate/gate2.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/app_permissions.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/camera_provider.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/configure_duty_alarms.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/visitor_settings.dart';
import 'package:flutter_onegate/presentation/features/staff/ui/staff_home_view.dart';
import 'package:flutter_onegate/presentation/features/missed_approval/widget/time_provider.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
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
  String? selectedGateName;
  String? cameraValue;
  final _flutterKioskMode = FlutterKioskMode.instance();

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
    getSelectedGate();
    getCameraValue();
    _initializeRole();
  }

  void _enableKioskMode() async {
    try {
      await _flutterKioskMode.start();
    } catch (e) {
      print("Error starting kiosk mode: $e");
    }
  }

  void _showCameraSettings(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final cameraProvider =
                Provider.of<CameraSettingsProvider>(context, listen: false);
            _cameraValue =
                cameraProvider.selectedCameraValue; // Get the selected value

            return Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: Theme.of(context).colorScheme.surface,
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Camera',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shrinkWrap: true,
                    itemCount: _cameraItems.length,
                    itemBuilder: (context, index) {
                      final item = _cameraItems[index];
                      return RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        fillColor: WidgetStateProperty.all(Colors.black),
                        title: Text(
                          item.label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        value: item.value,
                        groupValue: _cameraValue,
                        // Reflect selected value
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _cameraValue = value;
                            });
                            cameraProvider
                                .updateCameraValue(value); // Save selection
                          }
                        },
                      );
                    },
                  ),
                  CustomLargeBtn(
                    text: 'Confirm',
                    onPressed: () async {
                      final role = await GateStorage().getRole();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GateDashboardView(),
                        ),
                      );
                      // Navigator.pop(context); // Close modal
                      // if (role == 'admin' || role == 'master') {
                      //   Navigator.push(
                      //     context,
                      //     MaterialPageRoute(
                      //       builder: (context) => AdminDashboardView(),
                      //     ),
                      //   );
                      // } else {
                      //   Navigator.push(
                      //     context,
                      //     MaterialPageRoute(
                      //       builder: (context) => GateDashboardView(),
                      //     ),
                      //   );
                      // }
                    },
                  ),
                  const SizedBox(height: 50.0),
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
                          Colors.black,
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

  void _showVisitorApprovalTime(BuildContext context) {
    int selectedValue =
        context.read<VisitorApprovalTimeProvider>().approvalTime;

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
                    'Select Approval Time',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: 16.0),
                  ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shrinkWrap: true,
                    itemCount: _visitorApprovalTimeItems.length,
                    itemBuilder: (context, index) {
                      final item = _visitorApprovalTimeItems[index];
                      return RadioListTile<int>(
                        contentPadding: EdgeInsets.zero,
                        fillColor: WidgetStateProperty.all(Colors.black),
                        title: Text(
                          item.label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        value: int.parse(item.value),
                        groupValue: selectedValue,
                        onChanged: (int? value) {
                          setState(() {
                            selectedValue = value!;
                          });
                        },
                      );
                    },
                  ),
                  CustomLargeBtn(
                    text: 'Confirm',
                    onPressed: () {
                      context
                          .read<VisitorApprovalTimeProvider>()
                          .setApprovalTime(selectedValue);
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
                          Colors.black,
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

  String? role;

  Future<void> _initializeRole() async {
    role = await GateStorage().getRole();
    setState(() {});
  }

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
      pageTitle: "Settings",
      pageBody: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SecondarySettingsTile(
              title: 'Gate Settings',
            ),
            // if (role == "admin" || role == "master")
            PrimarySettingsTile(
              icon: Ionicons.people_outline,
              title: 'Staffs',
              subtitle: 'View your society staffs',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StaffScreen(),
                  ),
                );
              },
            ),
            // Gate Settings (for Admin and Master only)
            if (role == "admin" || role == "master")
              PrimarySettingsTile(
                icon: Ionicons.grid_outline,
                title: 'Gate Settings',
                subtitle:
                    'Current Preference: ${selectedGateName ?? "Not Selected Gate"}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GateSelectionView(),
                    ),
                  );
                },
              ),
            if (role == "admin" || role == "master")
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
            // Visitor Settings (for Admin and Master only)
            // if (role == "admin" || role == "master")
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
            // if (role == "admin" || role == "master")

            PrimarySettingsTile(
              icon: Ionicons.time_outline,
              title: 'Visitor Approval Time',
              subtitle:
                  'Current Preference: ${context.watch<VisitorApprovalTimeProvider>().approvalTime} seconds',
              onTap: () {
                _showVisitorApprovalTime(context);
              },
            ),

            if (role == "admin" || role == "master")
              PrimarySettingsTile(
                icon: Ionicons.alarm_outline,
                title: 'Configure Duty Alarms',
                subtitle: 'Enable/Disable Duty Alarms',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConfigureDutyAlarms(),
                    ),
                  );
                },
              ),
            SecondarySettingsTile(
              title: 'Application Settings',
            ),
            // Camera Settings (for all roles)
            PrimarySettingsTile(
              icon: Ionicons.camera_outline,
              title: 'Camera Settings',
              subtitle:
                  "Current Preference: ${context.watch<CameraSettingsProvider>().selectedCameraValue ?? "Not Selected Camera"}",
              onTap: () {
                _showCameraSettings(context);
              },
            ),
            if (role == "admin" || role == "master")
              PrimarySettingsTile(
                icon: Ionicons.file_tray_full_outline,
                title: 'Data Storage',
                subtitle:
                    'Current Preference: ${_dataStorageValue ?? "6 Months"}',
                onTap: () {
                  _showDataStorage(context);
                },
              ),
            if (role == "admin" || role == "master")
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
            // Self Entry Settings (for all roles)
            PrimarySettingsTile(
              icon: Ionicons.options_outline,
              title: 'Self Entry Settings',
              subtitle: 'Enable/Disable Self Entry',
              onTap: () {
                _preferenceUtils.setIsSelfTapIn(true);
                _enableKioskMode();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SelfHomeView(),
                  ),
                );
              },
            ),
            if (role == "admin" || role == "master")
              PrimarySettingsTile(
                icon: Ionicons.shield_half_outline,
                title: 'Change Password',
                subtitle: 'Change your password',
                onTap: () {
                  // Add password change logic here
                },
              ),
            if (role == "admin" || role == "master")
              PrimarySettingsTile(
                icon: Ionicons.language_outline,
                title: 'Change Language',
                subtitle: 'Current Preference: ${_languageValue ?? "English"}',
                onTap: () {
                  _showLanguageSettings(context);
                },
              ),
            // Logout (for all roles)
            PrimarySettingsTile(
              icon: Ionicons.log_out_outline,
              title: 'Logout',
              subtitle: 'Logout from the app',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Row(
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Confirm Logout',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Are you sure you want to logout?',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'This action cannot be undone.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            elevation: 0,
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            logout(context);
                          },
                          child: Text(
                            'Logout',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      actionsPadding: EdgeInsets.all(16),
                      actionsAlignment: MainAxisAlignment.end,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> logout(BuildContext context) async {
    try {
      log("Attempting logout...");
      await keycloakWrapper.logout();
      log("Keycloak session ended.");

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Clear all stored preferences
      log("Preferences cleared.");

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => MyAppLogin()),
            (route) => false,
      );
    } catch (e, st) {
      log("Logout failed: $e\n$st");
      // Optionally show a SnackBar or AlertDialog to inform the user
    }
  }

  Future<void> getSelectedGate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedGateName = prefs.getString('selected_gate');
    });
  }

  Future<void> getCameraValue() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      cameraValue = prefs.getString('selected_camera');
    });
  }
}

class PrimarySettingsTile extends StatelessWidget {
  const PrimarySettingsTile({
    super.key,
    this.icon,
    this.leadingIcon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.subtitleWidget,
    this.trailing,
    this.titleStyle,
    this.subtitleStyle,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? leadingIcon;
  final Widget? subtitleWidget;
  final TextStyle? subtitleStyle;
  final TextStyle? titleStyle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: leadingIcon ??
          Icon(
            icon,
            size: 22,
            color: Theme.of(context).colorScheme.onSurface,
          ),
      title: Text(
        title,
        style: titleStyle ?? Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: subtitleWidget ??
          Text(
            subtitle ?? '',
            style: subtitleStyle ??
                Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 16,
                      color:
                          Theme.of(context).colorScheme.onSurface.withOpacity(
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
