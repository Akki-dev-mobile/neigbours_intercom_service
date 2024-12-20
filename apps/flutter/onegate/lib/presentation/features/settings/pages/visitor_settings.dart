import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:flutter_onegate/purposeProvider.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:provider/provider.dart';

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
  final provider1 = PurposeProvider();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadToggleValues();
    // provider1.fetchPurposes();
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

  void _updateToggleValue(bool value) {
    PreferenceUtils.getInstance().then((prefs) {
      prefs.setToogleValue(value);
    }).catchError((error) {
      print("Failed to save toggle value: $error");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PurposeProvider>(
      builder: (context, provider, child) {
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
                          overflow: TextOverflow.ellipsis, // Prevent overflow
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Set visitor's purpose as mandatory",
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis, // Prevent overflow
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: provider.isPurposeToggleOn,
                    onChanged: (value) async {
                      await provider.setPurposeToggleState(value);
                      if (value) {
                        provider.fetchPurposes(remoteDataSource);
                      } else {
                        // Clear values from SharedPreferences
                        await provider.clearSavedPurposes();
                      }
                      setState(() {
                        _isExpanded = value; // Update expansion state
                      });
                    },
                  ),
                ],
              ),
              if (_isExpanded) ...[
                provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    // : provider.purposes == null || provider.purposes!.isEmpty
                    //     ? const Center(child: Text("No purposes available"))
                    : Column(
                        children: [
                          ...provider.purposes!.map((purpose) {
                            return ListTile(
                              leading: purpose.purpose_img.isNotEmpty
                                  ? Image.network(
                                      purpose.purpose_img,
                                      width: 40,
                                      height: 40,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Icon(Icons.error),
                                    )
                                  : Icon(Icons.image),
                              title: Text(
                                purpose.purpose_category_name,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Checkbox(
                                value: purpose.isSelected,
                                onChanged: (isChecked) {
                                  provider.updatePurposeSelection(
                                    provider.purposes!.indexOf(purpose),
                                    isChecked ?? false,
                                  );

                                  provider
                                      .saveSelectedPurposes(provider.purposes!);
                                },
                              ),
                            );
                          }).toList(),
                          CustomLargeBtn(
                            onPressed: () {
                              final selectedPurposes = provider.purposes!
                                  .where((p) => p.isSelected)
                                  .toList();
                              provider.saveSelectedPurposes(selectedPurposes);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Purposes saved successfully!"),
                                ),
                              );
                            },
                            text: "Confirm",
                          ),
                        ],
                      ),
              ]
            ],
          ),
        );
      },
    );
  }
}
