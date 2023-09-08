part of 'gate_selection_bloc.dart';

@immutable
abstract class GateSelectionEvent {}

class GateSelectionInitialEvent extends GateSelectionEvent {}

class GateSelectionLoadingEvent extends GateSelectionEvent {}

class GateSelectionSuccessEvent extends GateSelectionEvent {
  final List<Gate> gates;
  GateSelectionSuccessEvent(this.gates);
}


