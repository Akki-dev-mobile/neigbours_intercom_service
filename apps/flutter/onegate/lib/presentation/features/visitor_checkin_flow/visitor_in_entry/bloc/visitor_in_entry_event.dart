part of 'visitor_in_entry_bloc.dart';

// Events
@immutable
abstract class VisitorInEntryEvent {}

class VIEGuestFormSubmitButtonPressedEvent extends VisitorInEntryEvent {
  final Visitor? searchedVisitor;
  final String? guestName;
  final String guestComingFrom;
  final int guestCount;
  final PurposeCategory1 purposeCategory;
  final String mobile;
  final String? carNumber;

  VIEGuestFormSubmitButtonPressedEvent({
    this.searchedVisitor,
    this.guestName,
    required this.guestComingFrom,
    required this.guestCount,
    required this.purposeCategory,
    required this.mobile,
    this.carNumber,
  });
}

class VIECameraButtonPressedEvent extends VisitorInEntryEvent {
  final Visitor? visitor;
  final PurposeCategory1? purposeCategory;
  final File? imageFile;
  final String? operation;

  VIECameraButtonPressedEvent({
    this.visitor,
    this.purposeCategory,
    this.imageFile,
    this.operation,
  });
}
