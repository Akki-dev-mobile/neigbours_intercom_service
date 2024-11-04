// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/gate_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/entities/gate/gate2.dart';
import 'package:flutter_onegate/domain/use_cases/gate_usecase.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/bloc/gate_selection_bloc.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';

import '../../dashboard/admin/pages/admin_dashboard_view.dart';

class GateSelectionView extends StatefulWidget {
  const GateSelectionView({Key? key}) : super(key: key);

  @override
  State<GateSelectionView> createState() => _GateSelectionViewState();
}

class _GateSelectionViewState extends State<GateSelectionView> {
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  Gate? storedGate, selectedGate;

  final GateSelectionBloc gateBloc = GateSelectionBloc(
    GateUseCase(
      GateRepositoryImpl(
        RemoteDataSource(DioSingleton.instance1,DioSingleton.instance2,DioSingleton.instance3),
      ),
    ),
  );

  @override
  void initState() {
    super.initState();
    gateBloc.add(GateSelectionInitialEvent());
    storedGate = _preferenceUtils.getSelectedGate();
    selectedGate = storedGate;
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
            if (storedGate != null && selectedGate != null) {
              if (storedGate!.id == selectedGate!.id) {
                for (var gate in successState.gates) {
                  if (gate.gateName == storedGate!.gateName) {
                    gate.isSelected = true;
                    selectedGate = gate;
                  }
                }
              } else {
                bool anyGateSelected =
                    successState.gates.any((gate) => gate.isSelected);
                if (!anyGateSelected && successState.gates.isNotEmpty) {
                  successState.gates[0].isSelected = true;
                  selectedGate = successState.gates[0];
                }
              }
            }
            if (storedGate == null) {
              bool anyGateSelected =
                  successState.gates.any((gate) => gate.isSelected);
              if (!anyGateSelected && successState.gates.isNotEmpty) {
                successState.gates[0].isSelected = true;
                selectedGate = successState.gates[0];
              }
            }

            return MyScrollView(
              pageTitle: 'Gate Selection',
              pageBody: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Select your gate',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  ...List.generate(successState.gates.length, (index) {
                    List<Gate> gatesList = successState.gates;
                    return GateSettingListTile(
                      switchValue: gatesList[index].isSelected,
                      onChanged: (value) => {
                        setState(() {
                          for (var gate in gatesList) {
                            gate.isSelected = false;
                            print(gate.isSelected);
                          }
                          gatesList[index].isSelected = true;
                          selectedGate = gatesList[index];
                        })
                      },
                      title: successState.gates[index].gateName ?? 'Unknown Gate',
                      subtitle:
                          'Enable/Disable ${successState.gates[index].gateName}',
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

class GateSettingListTile extends StatefulWidget {
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
  State<GateSettingListTile> createState() => _GateSettingListTileState();
}

class _GateSettingListTileState extends State<GateSettingListTile> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: widget.leadingIcon != null
          ? CircleAvatar(
              // backgroundColor: Color(0X101973E9),
              backgroundColor: Color(0xffFFEBE6),
              radius: 22,
              child: Icon(
                size: 24,
                widget.leadingIcon,
                // color: Color(0XFF1973E9),
                color: Colors.black,
              ),
            )
          : null,
      title: Text(
        widget.title,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        widget.subtitle,
        style: Theme.of(context).textTheme.labelSmall,
      ),
      trailing: Switch(
        inactiveThumbColor: Theme.of(context).colorScheme.onBackground,
        inactiveTrackColor:
            Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
        value: widget.switchValue,
        onChanged: widget.onChanged,
      ),
    );
  }
}
