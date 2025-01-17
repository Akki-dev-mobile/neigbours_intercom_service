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
                        const Center(
                          child: Text(
                            "No purposes available",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
                      if (purposeProvider.purposes != null)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.85,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: purposeProvider.purposes!.length,
                            itemBuilder: (context, index) {
                              final purpose = purposeProvider.purposes![index];
                              return Container(
                                decoration: BoxDecoration(
                                  color: purpose.isSelected
                                      ? const Color(0xFFFFEBE6)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: purpose.isSelected
                                        ? const Color(0xffC08261)
                                        : Colors.grey.shade300,
                                    width: purpose.isSelected ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: () {
                                    purposeProvider.updatePurposeSelection(
                                      purposeProvider.purposes!.indexOf(purpose),
                                      !purpose.isSelected,
                                    );
                                    purposeProvider.saveSelectedPurposes(
                                      purposeProvider.purposes!,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    children: [
                                      // Main Content Container
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              // Purpose Image
                                              Container(
                                                width: 60,
                                                height: 60,
                                                padding: const EdgeInsets.all(8),
                                                child: Center(
                                                  child: purpose.image?.isNotEmpty ?? false
                                                      ? ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.network(
                                                      purpose.image!,
                                                      width: 44,
                                                      height: 44,
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (context, error, stackTrace) =>
                                                      const Icon(
                                                        Icons.image,
                                                        size: 40,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  )
                                                      : const Icon(
                                                    Icons.image,
                                                    size: 40,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              // Purpose Name
                                              Expanded(
                                                child: Center(
                                                  child: Text(
                                                    purpose.categoryName,
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: purpose.isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: purpose.isSelected
                                                          ? const Color(0xffC08261)
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Selection Indicator
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: purpose.isSelected
                                                ? const Color(0xffC08261)
                                                : Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: purpose.isSelected
                                                  ? const Color(0xffC08261)
                                                  : Colors.grey.shade400,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.check,
                                            size: 16,
                                            color: purpose.isSelected
                                                ? Colors.white
                                                : Colors.transparent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  )
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
