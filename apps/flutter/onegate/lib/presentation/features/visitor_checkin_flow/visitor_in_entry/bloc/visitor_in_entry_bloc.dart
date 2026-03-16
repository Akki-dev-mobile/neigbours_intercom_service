import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';

part 'visitor_in_entry_event.dart';
part 'visitor_in_entry_state.dart';

class VisitorInEntryBloc
    extends Bloc<VisitorInEntryEvent, VisitorInEntryState> {
  final VisitorUsecase _visitorUsecase;
  final VisitorLogUsecase _visitorLogUsecase;
  final PreferenceUtils _preferenceUtils;

  VisitorInEntryBloc(
    this._visitorUsecase,
    this._visitorLogUsecase,
  )   : _preferenceUtils = GetIt.I<PreferenceUtils>(),
        super(VisitorInEntryInitial()) {
    on<VIEGuestFormSubmitButtonPressedEvent>(_handleGuestFormSubmit);
    on<VIECameraButtonPressedEvent>(_handleCameraButton);
    on<VIEValidationErrorEvent>(_handleValidationError);
    on<VIENavigateToCameraEvent>(_handleNavigateToCamera);
  }

  void _handleValidationError(
    VIEValidationErrorEvent event,
    Emitter<VisitorInEntryState> emit,
  ) {
    emit(VisitorInEntryValidationErrorState(
      message: event.message,
      field: event.field,
    ));
  }

  void _handleNavigateToCamera(
    VIENavigateToCameraEvent event,
    Emitter<VisitorInEntryState> emit,
  ) {
    emit(VIENavigateToCameraState(
      event.visitor,
      event.purposeCategory,
      'update_image',
    ));
  }

  Future<void> _handleGuestFormSubmit(
    VIEGuestFormSubmitButtonPressedEvent event,
    Emitter<VisitorInEntryState> emit,
  ) async {
    try {
      final visitor = Visitor(
        name: event.guestName!,
        mobile: event.mobile,
        visitor_image: "",
        isStaff: event.searchedVisitor?.isStaff, // Preserve isStaff property
      );

      // Always navigate to camera for photo capture after purpose entry
      // This ensures a current photo is taken for security verification
      emit(VIENavigateToCameraState(
        event.searchedVisitor ?? visitor,
        event.purposeCategory,
        event.searchedVisitor == null ? 'new_visitor' : 'update_image',
      ));
    } catch (error) {
      emit(VisitorInEntryErrorState(message: error.toString()));
    }
  }

  Future<void> _handleCameraButton(
    VIECameraButtonPressedEvent event,
    Emitter<VisitorInEntryState> emit,
  ) async {
    emit(VisitorInEntryLoadingState());

    try {
      final imageUrl = await _uploadVisitorImage(event);
      if (imageUrl == null) {
        emit(VisitorInEntryErrorState(message: "Error uploading image"));
        return;
      }

      final updatedVisitor = event.visitor!..visitor_image = imageUrl;

      if (event.operation == "new_visitor") {
        await _handleNewVisitor(updatedVisitor, event.purposeCategory!, emit);
      } else {
        // For QR scan flow, we need to pass the visitorLog
        await _handleExistingVisitor(
            updatedVisitor, event.purposeCategory!, emit,
            isFromQRScan: event.isFromQRScan,
            isGatekeeperQRPasscodeEntry: event.isGatekeeperQRPasscodeEntry,
            visitorLog: event.visitorLog);
      }
    } catch (error) {
      emit(VisitorInEntryErrorState(message: error.toString()));
    }
  }

  Future<String?> _uploadVisitorImage(VIECameraButtonPressedEvent event) async {
    return _visitorUsecase.uploadImage(
      event.imageFile!,
      event.visitor!.mobile ?? "",
      _preferenceUtils.getSelectedCompany()?.companyId ?? 0,
    );
  }

  Future<void> _handleNewVisitor(
    Visitor visitor,
    PurposeCategory1 purposeCategory,
    Emitter<VisitorInEntryState> emit,
  ) async {
    final createdVisitor = await _visitorUsecase.createVisitor(visitor);
    print("Visitor Name: ${createdVisitor!.name}, Visitor Details:  ");
    emit(VIENavigateToUnitSelectionState(createdVisitor, purposeCategory));
  }

  Future<void> _handleExistingVisitor(Visitor visitor,
      PurposeCategory1 purposeCategory, Emitter<VisitorInEntryState> emit,
      {bool isFromQRScan = false,
      bool isGatekeeperQRPasscodeEntry = false,
      VisitorLog? visitorLog}) async {
    final isUpdated = await _visitorUsecase.updateVisitor(visitor);
    if (isUpdated) {
      // Gatekeeper QR flow must go through unit selection - entry only after all details submitted
      if (isFromQRScan &&
          visitorLog != null &&
          !isGatekeeperQRPasscodeEntry) {
        emit(VIENavigateToRequestScreenState(
            visitor, purposeCategory, visitorLog));
      } else {
        emit(VIENavigateToUnitSelectionState(visitor, purposeCategory));
      }
    } else {
      emit(VisitorInEntryErrorState(message: "Error updating visitor image"));
    }
  }
}
