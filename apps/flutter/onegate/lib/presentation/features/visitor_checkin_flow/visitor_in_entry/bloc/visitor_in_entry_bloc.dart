import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/repositories/visitor_repo.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';
import 'package:onegate_client/onegate_client.dart';

part 'visitor_in_entry_event.dart';
part 'visitor_in_entry_state.dart';

class VisitorInEntryBloc
    extends Bloc<VisitorInEntryEvent, VisitorInEntryState> {
  final VisitorUsecase _visitorUsecase;
  final VisitorLogUsecase _visitorLogUsecase;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();

  VisitorInEntryBloc(this._visitorUsecase, this._visitorLogUsecase)
      : super(VisitorInEntryInitial()) {
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
      Emitter<VisitorInEntryState> emit) async {
    Visitor? selectedVisitor = event.searchedVisitor;
    emit(VisitorInEntryLoadingState());
    selectedVisitor ??= await _visitorUsecase.createVisitor(Visitor(
        name: event.guestName!, mobile: event.mobile, visitor_image: ''));
    emit(VIENavigateToUnitSelectionState(
        selectedVisitor!, event.purposeCategory));
    emit(VisitorInEntryInitial());
  }
}
