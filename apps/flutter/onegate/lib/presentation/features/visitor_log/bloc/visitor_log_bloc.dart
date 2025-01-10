import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:onegate_client/onegate_client.dart';

part 'visitor_log_event.dart';
part 'visitor_log_state.dart';

class VisitorLogBloc extends Bloc<VisitorLogEvent, VisitorLogState> {
  final VisitorLogUsecase visitorLogUseCase;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  VisitorLogBloc(this.visitorLogUseCase) : super(VisitorLogInitial()) {
    on<FetchVisitorLogEvent>(fetchVisitorLogEvent);
    on<CheckOutEvent>(checkOutEvent);
    on<FetchCheckInLogEvent>(fetchCheckInLogEvent);
    on<FetchCheckOutLogEvent>(fetchCheckOutLogEvent);
  }
  String getFormattedDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  FutureOr<void> fetchVisitorLogEvent(
      FetchVisitorLogEvent event, Emitter<VisitorLogState> emit) async {
    try {
      emit(VisitorLogLoadingState());
      DateTime today = DateTime.now();

      // Get today's date in the desired format (yyyy-MM-dd)
      String formattedDate = getFormattedDate(today);
      final visitorLogs = await visitorLogUseCase.fetchAllLogs(
          _preferenceUtils.getSelectedCompany()?.companyId ?? 0, formattedDate);


      emit(VisitorLogSuccessState(visitorLogs));
    } catch (error) {
      emit(VisitorLogErrorState(error.toString()));
    }
  }

  FutureOr<void> checkOutEvent(
      CheckOutEvent event, Emitter<VisitorLogState> emit) async {
    try {
      emit(VisitorLogLoadingState());
      final response = await visitorLogUseCase.checkOut(event.visitorLog);
      if (response) {
        if (event.screenType == 'Visitor In') {
          emit(VisitorCheckInLogSuccessState());
        } else if (event.screenType == "In Out Book") {

          DateTime today = DateTime.now();

          // Get today's date in the desired format (yyyy-MM-dd)
          String formattedDate = getFormattedDate(today);
          final visitorLogs = await visitorLogUseCase.fetchAllLogs(
              _preferenceUtils.getSelectedCompany()?.companyId ?? 0, formattedDate);
          emit(VisitorLogSuccessState(visitorLogs));
        } else {
          emit(VisitorCheckOutLogSuccessState());
        }
      } else {
        emit(VisitorLogErrorState('Something went wrong'));
      }
    } catch (error) {
      emit(VisitorLogErrorState(error.toString()));
    }
  }

  FutureOr<void> fetchCheckInLogEvent(
      FetchCheckInLogEvent event, Emitter<VisitorLogState> emit) async {
    try {
      emit(VisitorLogLoadingState());
      DateTime today = DateTime.now();

      // Get today's date in the desired format (yyyy-MM-dd)
      String formattedDate = getFormattedDate(today);
      final visitorLogs = await visitorLogUseCase.fetchCheckInVisitorLog(
          _preferenceUtils.getSelectedCompany()?.companyId ?? 0, formattedDate);
      emit(VisitorLogSuccessState(visitorLogs));
    } catch (error) {
      emit(VisitorLogErrorState(error.toString()));
    }
  }

  FutureOr<void> fetchCheckOutLogEvent(
      FetchCheckOutLogEvent event, Emitter<VisitorLogState> emit) async {
    try {
      emit(VisitorLogLoadingState());
      DateTime today = DateTime.now();

      // Get today's date in the desired format (yyyy-MM-dd)
      String formattedDate = getFormattedDate(today);
      final visitorLogs = await visitorLogUseCase.fetchCheckOutLogs(
          _preferenceUtils.getSelectedCompany()?.companyId ?? 0, formattedDate);
      emit(VisitorLogSuccessState(visitorLogs));
    } catch (error) {
      emit(VisitorLogErrorState(error.toString()));
    }
  }
}
