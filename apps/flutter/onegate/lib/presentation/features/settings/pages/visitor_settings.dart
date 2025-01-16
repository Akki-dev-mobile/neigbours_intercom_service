import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/visitor_Settings_provider.dart';
import 'package:flutter_onegate/purposeProvider.dart';
import 'package:provider/provider.dart';

class VisitorSettingsView extends StatefulWidget {
  @override
  State<VisitorSettingsView> createState() => _VisitorSettingsViewState();
}

class _VisitorSettingsViewState extends State<VisitorSettingsView> {
  final RemoteDataSource remoteDataSource = RemoteDataSource(
    DioSingleton.instance1,
    DioSingleton.instance2,
    DioSingleton.instance3,
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VisitorSettingsProvider()),
        ChangeNotifierProvider(create: (_) => PurposeProvider()),
      ],
      child: Consumer2<VisitorSettingsProvider, PurposeProvider>(
        builder: (context, visitorProvider, purposeProvider, child) {
          final hasChanges = visitorProvider.hasChanges();

          return MyScrollView(
            backButtonPressed: () => Navigator.pop(context),
            pageTitle: 'Visitor Settings',
            pageBody: Column(
              children: [
                // Visitor's Address Setting
                GateSettingListTile(
                  switchValue: visitorProvider.visitorsAddress,
                  onChanged: visitorProvider.updateVisitorsAddress,
                  title: "Visitor's Address",
                  subtitle: "Set visitor's address as mandatory",
                ),

                // Member's Approval Setting
                GateSettingListTile(
                  switchValue: visitorProvider.membersApproval,
                  onChanged: visitorProvider.updateMembersApproval,
                  title: "Member's Approval",
                  subtitle: "Set member's approval as mandatory",
                ),

                // Gate ID Setting
                GateSettingListTile(
                  switchValue: visitorProvider.gateIdToggleValue,
                  onChanged: visitorProvider.updateGateIdToggleValue,
                  title: "Gate Id",
                  subtitle: "Set gate id as mandatory",
                ),

                // Visitor Card Number Setting
                GateSettingListTile(
                  switchValue: visitorProvider.visitorCardNumber,
                  onChanged: visitorProvider.updateVisitorCardNumber,
                  title: "Visitor Card Number",
                  subtitle: "Set visitor card number as mandatory",
                ),

                // Visitor's Purpose Setting
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Visitor's Purpose",
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Set visitor's purpose as mandatory",
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: purposeProvider.isPurposeToggleOn,
                      onChanged: (value) async {
                        await purposeProvider.setPurposeToggleState(value);

                        if (value) {
                          await purposeProvider.fetchPurposes(remoteDataSource);
                        } else {
                          await purposeProvider.clearSavedPurposes();
                        }
                      },
                    ),
                  ],
                ),

                // Expanded Purpose List
                if (purposeProvider.isPurposeToggleOn)
                  purposeProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                    children: [
                      if (purposeProvider.purposes?.isEmpty ?? true)
                        const Text("No purposes available"),
                      if (purposeProvider.purposes != null)
                        ...purposeProvider.purposes!.map((purpose) {
                          return ListTile(
                            leading: purpose.image!.isNotEmpty
                                ? Image.network(
                              purpose.image ?? "",
                              width: 40,
                              height: 40,
                              errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.error),
                            )
                                : const Icon(Icons.image),
                            title: Text(
                              purpose.categoryName,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Checkbox(
                              value: purpose.isSelected,
                              onChanged: (isChecked) {
                                purposeProvider.updatePurposeSelection(
                                  purposeProvider.purposes!.indexOf(purpose),
                                  isChecked ?? false,
                                );
                                purposeProvider.saveSelectedPurposes(
                                    purposeProvider.purposes!);
                              },
                            ),
                          );
                        }).toList(),
                      // CustomLargeBtn(
                      //   onPressed: () {
                      //     final selectedPurposes = purposeProvider.purposes!
                      //         .where((p) => p.isSelected)
                      //         .toList();
                      //     purposeProvider.saveSelectedPurposes(selectedPurposes);
                      //
                      //     ScaffoldMessenger.of(context).showSnackBar(
                      //       const SnackBar(
                      //         content: Text("Purposes saved successfully!"),
                      //       ),
                      //     );
                      //   },
                      //   text: "Confirm",
                      // ),
                    ],
                  ),
              ],
            ),
            floatingActionButton: hasChanges
                ? CustomLargeBtn(
              text: 'Confirm',
              onPressed: () async {
                visitorProvider.saveChanges();
                final selectedPurposes = purposeProvider.purposes!
                    .where((p) => p.isSelected)
                    .toList();
                purposeProvider.saveSelectedPurposes(selectedPurposes);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Purposes saved successfully!"),
                  ),
                );
                final role = await GateStorage().getRole();
                if (role == 'admin' || role == 'master') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminDashboardView(),
                    ),
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GateDashboardView(),
                    ),
                  );
                }
              },
            )
                : null,
          );
        },
      ),
    );
  }
}