part of 'visitor_in_entry_bloc.dart';

// States
@immutable
abstract class VisitorInEntryState {}

class VisitorInEntryInitial extends VisitorInEntryState {}

class VisitorInEntryLoadingState extends VisitorInEntryState {}

class VisitorInEntryErrorState extends VisitorInEntryState {
  final String message;

  VisitorInEntryErrorState({required this.message});
}

class VisitorInEntryValidationErrorState extends VisitorInEntryState {
  final String message;
  final String field;

  VisitorInEntryValidationErrorState(
      {required this.message, required this.field});
}

abstract class VisitorInEntryActionState extends VisitorInEntryState {}

class VIENavigateToUnitSelectionState extends VisitorInEntryActionState {
  final Visitor visitor;
  final PurposeCategory1 purposeCategory;

  VIENavigateToUnitSelectionState(this.visitor, this.purposeCategory);
}

class VIENavigateToCameraState extends VisitorInEntryActionState {
  final Visitor visitor;
  final PurposeCategory1 purposeCategory;
  final String operation;

  VIENavigateToCameraState(this.visitor, this.purposeCategory, this.operation);
}
