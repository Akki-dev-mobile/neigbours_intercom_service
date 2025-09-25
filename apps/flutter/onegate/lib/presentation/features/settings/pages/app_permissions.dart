// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';

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
      backButtonPressed: () {
        Navigator.pop(context);
      },
      pageTitle: AppLocalizations.of(context)!.gateSettings,
      pageBody: Column(
        children: [
          GateSettingListTile(
            switchValue: _drawoverotherapps,
            onChanged: (value) {
              setState(() {
                _drawoverotherapps = value;
              });
            },
            title: AppLocalizations.of(context)!.allowDrawOverApps,
            subtitle: AppLocalizations.of(context)!.drawOverAppsDescription,
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
            title: AppLocalizations.of(context)!.allowEscapeDND,
            subtitle: AppLocalizations.of(context)!.escapeDNDDescription,
          ),
        ],
      ),
    );
  }
}
