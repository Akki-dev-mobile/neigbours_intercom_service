// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/gate_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/use_cases/gate_usecase.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/bloc/gate_selection_bloc.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';

import '../../dashboard/admin/pages/admin_dashboard_view.dart';
import '../../gate_config/ui/gate_config_view.dart';

class GateSelectionView extends StatefulWidget {
  const GateSelectionView({Key? key}) : super(key: key);

  @override
  State<GateSelectionView> createState() => _GateSelectionViewState();
}

class _GateSelectionViewState extends State<GateSelectionView> {
  final GateSelectionBloc gateBloc = GateSelectionBloc(
    GateUseCase(
      GateRepositoryImpl(
        RemoteDataSource(dioInstance),
      ),
    ),
  );
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
            contentPadding: EdgeInsets.zero,
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
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.bottomToTop,
                child: GateConfigView(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class GateSettingListTile extends StatelessWidget {
  const GateSettingListTile({
    Key? key,
    required this.switchValue,
    required this.onChanged,
    required this.title,
    required this.subtitle,
    this.leadingIcon,
  }) : super(key: key);

  final bool switchValue;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: leadingIcon != null
          ? CircleAvatar(
              // backgroundColor: Color(0X101973E9),
              backgroundColor: Color(0xffFFEBE6),
              radius: 22,
              child: Icon(
                size: 24,
                leadingIcon,
                // color: Color(0XFF1973E9),
                color: Colors.black,
              ),
            )
          : null,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: switchValue,
        onChanged: onChanged,
      ),
    );
  }
}
