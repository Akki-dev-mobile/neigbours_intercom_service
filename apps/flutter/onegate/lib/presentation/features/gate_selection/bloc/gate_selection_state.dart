part of 'gate_selection_bloc.dart';

@immutable
abstract class GateSelectionState {}

abstract class GateSelectionActionState extends GateSelectionState {}

 class GateSelectionInitialState extends GateSelectionState {}

 class GateSelectionLoadingState extends GateSelectionState {}

 class GateSelectionSuccessState extends GateSelectionState {
  final List<Gate> gates;
  GateSelectionSuccessState(this.gates);
}
 class GateSelectionErrorState extends GateSelectionActionState {
  String message;
  GateSelectionErrorState({required this.message });
}


