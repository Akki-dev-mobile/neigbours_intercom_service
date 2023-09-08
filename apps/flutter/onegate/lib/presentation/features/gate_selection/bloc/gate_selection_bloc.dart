import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/use_cases/gate_usecase.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';

part 'gate_selection_event.dart';
part 'gate_selection_state.dart';

class GateSelectionBloc extends Bloc<GateSelectionEvent, GateSelectionState> {
  final GateUseCase _gateUseCase;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  GateSelectionBloc(this._gateUseCase) : super(GateSelectionInitial()) {
    on<GateSelectionEvent>((event, emit) {
      // TODO: implement event handler
    });
  }
}
