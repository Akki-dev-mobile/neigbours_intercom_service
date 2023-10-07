import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'visitor_in_entry_event.dart';
part 'visitor_in_entry_state.dart';

class VisitorInEntryBloc
    extends Bloc<VisitorInEntryEvent, VisitorInEntryState> {
  VisitorInEntryBloc() : super(VisitorInEntryInitial()) {
    on<VisitorInEntryEvent>(visitorInEntryInitialEvent);

    on<VIEGuestNameMicrophoneButtonPressedEvent>(
        vieGuestNameMicrophoneButtonPressedEvent);
    on<VIEGuestComingFromMicrophoneButtonPressedEvent>(
        vieGuestComingFromMicrophoneButtonPressedEvent);
    on<VIEIncrementGuestCountButtonPressedEvent>(
        vieIncrementGuestCountButtonPressedEvent);
    on<VIEDecrementGuestCountButtonPressedEvent>(
        vieDecrementGuestCountButtonPressedEvent);
    on<VIEGuestFormSubmitButtonPressedEvent>(
        vieGuestFormSubmitButtonPressedEvent);
  }

  FutureOr<void> visitorInEntryInitialEvent(
      VisitorInEntryEvent event, Emitter<VisitorInEntryState> emit) {}

  FutureOr<void> vieGuestNameMicrophoneButtonPressedEvent(
      VIEGuestNameMicrophoneButtonPressedEvent event,
      Emitter<VisitorInEntryState> emit) {}

  FutureOr<void> vieGuestComingFromMicrophoneButtonPressedEvent(
      VIEGuestComingFromMicrophoneButtonPressedEvent event,
      Emitter<VisitorInEntryState> emit) {}

  FutureOr<void> vieIncrementGuestCountButtonPressedEvent(
      VIEIncrementGuestCountButtonPressedEvent event,
      Emitter<VisitorInEntryState> emit) {}

  FutureOr<void> vieDecrementGuestCountButtonPressedEvent(
      VIEDecrementGuestCountButtonPressedEvent event,
      Emitter<VisitorInEntryState> emit) {}

  FutureOr<void> vieGuestFormSubmitButtonPressedEvent(
      VIEGuestFormSubmitButtonPressedEvent event,
      Emitter<VisitorInEntryState> emit) {}
}
