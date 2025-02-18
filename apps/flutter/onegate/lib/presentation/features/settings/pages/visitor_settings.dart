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
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VisitorSettingsView extends StatefulWidget {
  @override
  State<VisitorSettingsView> createState() => _VisitorSettingsViewState();
}

class _VisitorSettingsViewState extends State<VisitorSettingsView> {
  String? selectedGateName;
  final RemoteDataSource remoteDataSource = RemoteDataSource();

  void initState() {
    super.initState();
    getSelectedGate();
  }

  Future<void> getSelectedGate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedGateName = prefs.getString('selected_gate');
    });
  }

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

                GateSettingListTile(
                  title: "Visitor's Purpose",
                  subtitle: "Set visitor's purpose as mandatory",
                  switchValue: purposeProvider.isPurposeToggleOn,
                  onChanged: (value) async {
                    await purposeProvider.setPurposeToggleState(value);

                    if (value) {
                      await purposeProvider.fetchPurposes(remoteDataSource);
                    } else {
                      await purposeProvider.clearSavedPurposes();
                    }
                  },
                ),

                if (purposeProvider.isPurposeToggleOn)
                  purposeProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            if (purposeProvider.purposes?.isEmpty ?? true)
                              const Center(
                                child: Text(
                                  "No purposes available",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            if (purposeProvider.purposes != null)
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 0.85,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                                  itemCount: purposeProvider.purposes!.length,
                                  itemBuilder: (context, index) {
                                    final purpose =
                                        purposeProvider.purposes![index];
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
                                        onTap: () async {
                                          purposeProvider
                                              .updatePurposeSelection(
                                            purposeProvider.purposes!
                                                .indexOf(purpose),
                                            !purpose.isSelected,
                                          );
                                          await purposeProvider
                                              .saveSelectedPurposes(
                                            purposeProvider.purposes!,
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Stack(
                                          children: [
                                            Center(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 12),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Center(
                                                      child: purpose.image
                                                                  ?.isNotEmpty ??
                                                              false
                                                          ? ClipRRect(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                              child:
                                                                  Image.network(
                                                                purpose.image!,
                                                                // width: 50,
                                                                // height: 50,
                                                                fit: BoxFit
                                                                    .contain,
                                                                errorBuilder: (context,
                                                                        error,
                                                                        stackTrace) =>
                                                                    const Icon(
                                                                  Icons.image,
                                                                  size: 40,
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                              ),
                                                            )
                                                          : const Icon(
                                                              Icons.image,
                                                              size: 40,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Expanded(
                                                      child: Center(
                                                        child: Text(
                                                          purpose.categoryName,
                                                          textAlign:
                                                              TextAlign.center,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            fontWeight: purpose
                                                                    .isSelected
                                                                ? FontWeight
                                                                    .bold
                                                                : FontWeight
                                                                    .normal,
                                                            color: purpose
                                                                    .isSelected
                                                                ? const Color(
                                                                    0xffC08261)
                                                                : Colors
                                                                    .black87,
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
                                                        ? const Color(
                                                            0xffC08261)
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
                      await visitorProvider.saveChanges();
                      final selectedPurposes = purposeProvider.purposes!
                          .where((p) => p.isSelected)
                          .toList();
                      purposeProvider.saveSelectedPurposes(selectedPurposes);
myFluttertoast(msg: "Changes saved successfully!");
                      final role = await GateStorage().getRole();
                      if (role == 'admin' || role == 'master') {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminDashboardView(),
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
