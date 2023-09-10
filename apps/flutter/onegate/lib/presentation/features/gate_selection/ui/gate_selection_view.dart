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

  @override
  void initState() {
    super.initState();
    gateBloc.add(GateSelectionInitialEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GateSelectionBloc, GateSelectionState>(
      bloc: gateBloc,
      listenWhen: (previous, current) => current is GateSelectionActionState,
      buildWhen: (previous, current) => current is! GateSelectionActionState,
      listener: (BuildContext context, GateSelectionState state) {
        switch (state.runtimeType) {
          case GateSelectionErrorState:
            final errorState = state as GateSelectionErrorState;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorState.message),
              ),
            );
            break;
          case GateSelectionNavigateToAdminDashActionState:
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              PageTransition(
                child: AdminDashboardView(),
                type: PageTransitionType.fade,
              ),
            );
            break;
          default:
            break;
        }
      },
      builder: (context, state) {
        switch (state.runtimeType) {
          case GateSelectionLoadingState:
            return LoaderView();
          case GateSelectionSuccessState:
            final successState = state as GateSelectionSuccessState;
            // Check if any gate is selected
            bool anyGateSelected =
                successState.gates.any((gate) => gate.isSelected);

            // If none of the gates is selected, set the first one as selected
            if (!anyGateSelected && successState.gates.isNotEmpty) {
              successState.gates[0].isSelected = true;
            }
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
                  ...List.generate(successState.gates.length, (index) {
                    return GateSettingListTile(
                      switchValue: successState.gates[index].isSelected,
                      onChanged: (value) => {
                        setState(() {
                          successState.gates.forEach((gate) {
                            gate.isSelected = false;
                          });
                          successState.gates[index].isSelected = true;
                        })
                      },
                      title: successState.gates[index].name,
                      subtitle:
                          'Enable/Disable ${successState.gates[index].name}',
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
                    gateBloc.add(
                        GateSelectionConfirmEvent(gates: successState.gates));
                  },
                ),
              ),
            );
          default:
            return Container();
        }
      },
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
