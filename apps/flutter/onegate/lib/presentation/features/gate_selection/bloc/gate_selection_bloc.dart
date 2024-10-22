import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/entities/gate/gate2.dart';
import 'package:flutter_onegate/domain/use_cases/gate_usecase.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';

part 'gate_selection_event.dart';
part 'gate_selection_state.dart';

class GateSelectionBloc extends Bloc<GateSelectionEvent, GateSelectionState> {
  final GateUseCase _gateUseCase;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  GateSelectionBloc(this._gateUseCase) : super(GateSelectionInitialState()) {
    on<GateSelectionInitialEvent>(gateSelectionInitialEvent);
    on<GateSelectionConfirmEvent>(gateSelectionConfirmEvent);
  }

  FutureOr<void> gateSelectionInitialEvent(
      GateSelectionInitialEvent event, Emitter<GateSelectionState> emit) async{
    emit(GateSelectionLoadingState());
    try {
      final response = await _gateUseCase.gateList(_preferenceUtils.getSelectedCompany()!.companyId);
      final List<Gate> gates = response!;
      emit(GateSelectionSuccessState(gates));
    } catch (e) {
      emit(GateSelectionErrorState(message: e.toString()));
    }
  }

  FutureOr<void> gateSelectionConfirmEvent(GateSelectionConfirmEvent event, Emitter<GateSelectionState> emit) {
    emit(GateSelectionLoadingState());
    try {
      _preferenceUtils.saveGatesList(event.gates);
      final selectedGate = event.gates.firstWhere((gate) => gate.isSelected == true);
      _preferenceUtils.setSelectedGate(selectedGate);
      emit(GateSelectionNavigateToAdminDashActionState());
    } catch (e) {
      emit(GateSelectionErrorState(message: e.toString()));
    }
  }
}
