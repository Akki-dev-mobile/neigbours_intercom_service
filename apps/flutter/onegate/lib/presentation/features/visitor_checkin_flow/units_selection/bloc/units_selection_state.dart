part of 'units_selection_bloc.dart';

@immutable
class UnitsSelectionState {}

class UnitsSelectionInitial extends UnitsSelectionState {}

class UnitsSelectionActionState extends UnitsSelectionState {}

class UnitsSelectionLoadingState extends UnitsSelectionState {}

class UnitsSelectionErrorState extends UnitsSelectionActionState {
  final String? message;

  UnitsSelectionErrorState({this.message});
}

class UnitSelectionSuccessState extends UnitsSelectionState {
  final List<Building>? buildings;
  final List<MemberUnits>? units;
  final Building? selectedBuilding;

  UnitSelectionSuccessState(this.selectedBuilding,
      {this.buildings, this.units});
}

class MemberFetchedState extends UnitsSelectionActionState {
  final List<Member>? members;

  MemberFetchedState(this.members);
}

class NavigateToRequestPermissionState extends UnitsSelectionActionState {
  final List<MemberUnits> unit;

  NavigateToRequestPermissionState(
      {required this.unit});
}
