part of 'visitor_in_entry_bloc.dart';

@immutable
class VisitorInEntryEvent {}

class VisitorInEntryInitialEvent extends VisitorInEntryEvent {}

class VIEGuestNameMicrophoneButtonPressedEvent extends VisitorInEntryEvent {}

class VIEGuestComingFromMicrophoneButtonPressedEvent
    extends VisitorInEntryEvent {}

class VIEIncrementGuestCountButtonPressedEvent extends VisitorInEntryEvent {}

class VIEDecrementGuestCountButtonPressedEvent extends VisitorInEntryEvent {}

class VIEGuestFormSubmitButtonPressedEvent extends VisitorInEntryEvent {
  final Visitor? searchedVisitor;
  final String? guestName;
  final String? guestComingFrom;
  final int? guestCount;
  final PurposeCategory purposeCategory;
  final String mobile;

  VIEGuestFormSubmitButtonPressedEvent(
      {this.searchedVisitor,
      this.guestName,
      this.guestComingFrom,
      this.guestCount,
      required this.purposeCategory,
      required this.mobile});
}

class VIECameraButtonPressedEvent extends VisitorInEntryEvent {
  final XFile? imageFile;
  final Visitor? visitor;
  final PurposeCategory? purposeCategory;
  final String? operation;

  VIECameraButtonPressedEvent(
      {this.imageFile, this.visitor, this.operation, this.purposeCategory});
}
