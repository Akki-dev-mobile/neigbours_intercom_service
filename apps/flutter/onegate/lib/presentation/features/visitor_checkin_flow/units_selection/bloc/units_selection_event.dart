part of 'units_selection_bloc.dart';

@immutable
abstract class UnitSelectionEvent {}

class UnitSelectionInitialEvent extends UnitSelectionEvent {}

class BuildingChipClickedEvent extends UnitSelectionEvent {
  final List<Building> buildings;
  final Building building;

  BuildingChipClickedEvent(this.building, this.buildings);
}

class UnitSelectedEvent extends UnitSelectionEvent {
  final MemberUnits unit;

  UnitSelectedEvent(this.unit);
}

class NextButtonClickedEvent extends UnitSelectionEvent {
  final List<MemberUnits> unit;
  

  NextButtonClickedEvent(
      {required this.unit});
}
