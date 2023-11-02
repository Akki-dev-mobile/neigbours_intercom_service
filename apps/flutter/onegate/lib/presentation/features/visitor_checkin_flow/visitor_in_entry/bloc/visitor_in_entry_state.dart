part of 'visitor_in_entry_bloc.dart';

@immutable
class VisitorInEntryState {}

abstract class VisitorInEntryActionState extends VisitorInEntryState {}

class VisitorInEntryInitial extends VisitorInEntryState {}

class VisitorInEntryLoadingState extends VisitorInEntryState {}

class VisitorInEntrySuccessState extends VisitorInEntryActionState {}

class VisitorInEntryErrorState extends VisitorInEntryActionState {}

class VIEGuestNameMicrophoneButtonPressedState
    extends VisitorInEntryActionState {}

class VIEGuestComingFromMicrophoneButtonPressedState
    extends VisitorInEntryActionState {}

class VIEIncrementGuestCountButtonPressedState
    extends VisitorInEntryActionState {}

class VIEDecrementGuestCountButtonPressedState
    extends VisitorInEntryActionState {}

class VIEGuestFormSubmitButtonPressedState extends VisitorInEntryActionState {}

class VIENavigateToUnitSelectionState extends VisitorInEntryActionState {
  final Visitor visitor;
  final PurposeCategory purposeCategory;
  VIENavigateToUnitSelectionState(this.visitor, this.purposeCategory);
}

class VIENavigateToCameraState extends VisitorInEntryActionState {
  final Visitor visitor;
  final PurposeCategory purposeCategory;
  VIENavigateToCameraState(this.visitor, this.purposeCategory);
}
