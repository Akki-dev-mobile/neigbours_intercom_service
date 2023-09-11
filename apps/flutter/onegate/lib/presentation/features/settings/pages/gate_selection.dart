// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';
import 'package:common_widgets/common_widgets.dart';

class GateSelectionView extends StatefulWidget {
  const GateSelectionView({Key? key}) : super(key: key);

  @override
  State<GateSelectionView> createState() => _GateSelectionViewState();
}

class _GateSelectionViewState extends State<GateSelectionView> {
  // List of gates
  List<Map<String, dynamic>> gates = [
    {'gate': 'Gate 1', 'switchValue': true}, // Gate 1 selected by default
    {'gate': 'Gate 2', 'switchValue': false},
    {'gate': 'Gate 3', 'switchValue': false},
    {'gate': 'Gate 4', 'switchValue': false},
    {'gate': 'Gate 5', 'switchValue': false},
  ];

  void _updateSwitchValue(bool newValue, int index) {
    setState(() {
      gates.forEach((gate) {
        gate['switchValue'] = false;
      });
      gates[index]['switchValue'] = newValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageTitle: 'Gate Selection',
      pageBody: Column(
        children: [
          ListTile(
            title: Text(
              'Select your gate',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 20,
              ),
            ),
          ),
          ...List.generate(gates.length, (index) {
            return GateSettingListTile(
              switchValue: gates[index]['switchValue'],
              onChanged: (value) => _updateSwitchValue(value, index),
              title: gates[index]['gate'],
              subtitle: 'Enable/Disable ${gates[index]['gate']}',
              // leadingIcon: Ionicons.grid_outline,
              leadingIcon: Symbols.gate,
            );
          }),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CustomLargeBtn(
          text: 'CONFIRM',
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.rightToLeft,
                child: AdminDashboardView(),
              ),
            );
          },
        ),
      ),
    );
  }
}
