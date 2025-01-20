import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';

part 'visitor_in_entry_event.dart';
part 'visitor_in_entry_state.dart';


class VisitorInEntryBloc extends Bloc<VisitorInEntryEvent, VisitorInEntryState> {
  final VisitorUsecase _visitorUsecase;
  final VisitorLogUsecase _visitorLogUsecase;
  final PreferenceUtils _preferenceUtils;

  VisitorInEntryBloc(
      this._visitorUsecase,
      this._visitorLogUsecase,
      ) : _preferenceUtils = GetIt.I<PreferenceUtils>(),
        super(VisitorInEntryInitial()) {
    on<VIEGuestFormSubmitButtonPressedEvent>(_handleGuestFormSubmit);
    on<VIECameraButtonPressedEvent>(_handleCameraButton);
  }

  Future<void> _handleGuestFormSubmit(
      VIEGuestFormSubmitButtonPressedEvent event,
      Emitter<VisitorInEntryState> emit,
      ) async {
    final visitor = Visitor(
      name: event.guestName!,
      mobile: event.mobile,
      visitor_image: "",
    );

    if (event.searchedVisitor == null ||
        event.searchedVisitor!.visitor_image?.isEmpty == true) {
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
        await _handleExistingVisitor(updatedVisitor, event.purposeCategory!, emit);
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
    if (createdVisitor != null) {
      emit(VIENavigateToUnitSelectionState(createdVisitor, purposeCategory));
    } else {
      emit(VisitorInEntryErrorState(message: "Error creating visitor"));
    }
  }

  Future<void> _handleExistingVisitor(
      Visitor visitor,
      PurposeCategory1 purposeCategory,
      Emitter<VisitorInEntryState> emit,
      ) async {
    final isUpdated = await _visitorUsecase.updateVisitor(visitor);
    if (isUpdated) {
      emit(VIENavigateToUnitSelectionState(visitor, purposeCategory));
    } else {
      emit(VisitorInEntryErrorState(message: "Error updating visitor image"));
    }
  }
}

