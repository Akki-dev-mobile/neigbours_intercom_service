part of 'visitor_in_entry_bloc.dart';

@immutable
class VisitorInEntryEvent {}

class VisitorInEntryInitialEvent extends VisitorInEntryEvent {}

class VIEGuestNameMicrophoneButtonPressedEvent extends VisitorInEntryEvent {}

class VIEGuestComingFromMicrophoneButtonPressedEvent
    extends VisitorInEntryEvent {}

class VIEIncrementGuestCountButtonPressedEvent extends VisitorInEntryEvent {}

class VIEDecrementGuestCountButtonPressedEvent extends VisitorInEntryEvent {}

class VIEGuestFormSubmitButtonPressedEvent extends VisitorInEntryEvent {}
