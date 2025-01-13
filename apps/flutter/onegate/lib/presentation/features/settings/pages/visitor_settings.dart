import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
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

                  GateSettingListTile(
                    switchValue: provider.visitorCardNumber,
                    onChanged: (value) {
                      provider.updateVisitorCardNumber(value);
                    },
                    title: "Visitor Card Number",
                    subtitle: "Set visitor card number as mandatory",
                  ),
                ],
              ),
              floatingActionButton: hasChanges
                  ? CustomLargeBtn(
                      text: 'Confirm',
                      onPressed: () async{
                        provider.saveChanges();
                        // Check the role and navigate accordingly
                        final role = await GateStorage().getRole();

                        print("role$role");
                        // Fetch the role
                        if (role == 'admin' || role == 'master') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminDashboardView(),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GateDashboardView(),
                            ),
                          );
                        }
                      },
                    )
                  : null);
        },
      ),
    );
  }
}
