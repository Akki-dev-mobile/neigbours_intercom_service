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
  final bool isFromQRScan;
  final VisitorLog? visitorLog;

  VIECameraButtonPressedEvent({
    this.visitor,
    this.purposeCategory,
    this.imageFile,
    this.operation,
    this.isFromQRScan = false,
    this.visitorLog,
  });
}

class VIEValidationErrorEvent extends VisitorInEntryEvent {
  final String message;
  final String field;

  VIEValidationErrorEvent({
    required this.message,
    required this.field,
  });
}

class VIENavigateToCameraEvent extends VisitorInEntryEvent {
  final Visitor visitor;
  final PurposeCategory1 purposeCategory;

  VIENavigateToCameraEvent({
    required this.visitor,
    required this.purposeCategory,
  });
}
