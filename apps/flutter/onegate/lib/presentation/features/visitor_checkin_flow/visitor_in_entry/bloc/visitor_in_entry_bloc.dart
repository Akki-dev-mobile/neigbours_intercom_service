import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
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
    on<VIECameraButtonPressedEvent>(vieCameraButtonPressedEvent);
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
    final visitor = Visitor(
      name: event.guestName!,
      mobile: event.mobile,
      visitor_image: "",
    );

    if (event.searchedVisitor == null ||
        event.searchedVisitor!.visitor_image.isEmpty) {
      emit(VIENavigateToCameraState(
        event.searchedVisitor ?? visitor,
        event.purposeCategory,
        event.searchedVisitor == null ? 'new_visitor' : 'update_image',
      ));
    } else {
      emit(VIENavigateToUnitSelectionState(
        event.searchedVisitor!,
        event.purposeCategory,
      ));
    }

    emit(VisitorInEntryInitial());
  }

  Future<void> vieCameraButtonPressedEvent(VIECameraButtonPressedEvent event,
      Emitter<VisitorInEntryState> emit) async {
    try {
      final imageUrl = await _visitorUsecase.uploadImage(
        event.imageFile!,
        event.visitor!.mobile,
        _preferenceUtils.getSelectedCompany()?.companyId ?? 0,
      );

      if (imageUrl == null || imageUrl.isEmpty) {
        emit(VisitorInEntryErrorState(message: "Error uploading image"));
        return;
      }

      if (event.operation == "new_visitor") {
        final visitor = await _visitorUsecase.createVisitor(event.visitor!);
        emit(VIENavigateToUnitSelectionState(
          visitor!,
          event.purposeCategory!,
        ));
      } else {
        event.visitor!.visitor_image = imageUrl;
        final isUpdated = await _visitorUsecase.updateVisitor(event.visitor!);

        if (!isUpdated) {
          emit(VisitorInEntryErrorState(
              message: "Error updating visitor image"));
        } else {
          emit(VIENavigateToUnitSelectionState(
            event.visitor!,
            event.purposeCategory!,
          ));
        }
      }
    } catch (error) {
      emit(VisitorInEntryErrorState(message: error.toString()));
    }
  }
}
