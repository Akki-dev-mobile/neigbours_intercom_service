part of 'gate_selection_bloc.dart';

@immutable
abstract class GateSelectionState {}

abstract class GateSelectionActionState extends GateSelectionState {}

final class GateSelectionInitialState extends GateSelectionState {}

final class GateSelectionLoadingState extends GateSelectionState {}

final class GateSelectionSuccessState extends GateSelectionState {
  final List<Gate> gates;
  GateSelectionSuccessState(this.gates);
}

final class GateSelectionErrorState extends GateSelectionActionState {
  String message;
  GateSelectionErrorState({required this.message});
}

class GateSelectionNavigateToAdminDashActionState
    extends GateSelectionActionState {}
