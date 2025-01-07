import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/visitor_Settings_provider.dart';
import 'package:provider/provider.dart';

class VisitorSettingsView extends StatelessWidget {
  const VisitorSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VisitorSettingsProvider(),
      child: Consumer<VisitorSettingsProvider>(
        builder: (context, provider, child) {
          // Track whether changes have been made
          final bool hasChanges = provider.hasChanges();

          return MyScrollView(
              backButtonPressed: () {
                Navigator.pop(context);
              },
              pageTitle: 'Visitor Settings',
              pageBody: Column(
                children: [
                  GateSettingListTile(
                    switchValue: provider.visitorsAddress,
                    onChanged: (value) {
                      provider.updateVisitorsAddress(value);
                    },
                    title: "Visitor's Address",
                    subtitle: "Set visitor's address as mandatory",
                  ),
                  GateSettingListTile(
                    switchValue: provider.membersApproval,
                    onChanged: (value) {
                      provider.updateMembersApproval(value);
                    },
                    title: "Member's Approval",
                    subtitle: "Set member's approval as mandatory",
                  ),
                  GateSettingListTile(
                    switchValue: provider.gateIdToggleValue,
                    onChanged: (value) {
                      provider.updateGateIdToggleValue(value);
                    },
                    title: "Gate Id",
                    subtitle: "Set gate id as mandatory",
                  ),
                ],
              ),
              floatingActionButton: hasChanges
                  ? CustomLargeBtn(
                      text: 'Confirm',
                      onPressed: () {
                        provider.saveChanges();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Changes saved successfully!"),
                          ),
                        );
                      },
                    )
                  : null);
        },
      ),
    );
  }
}
