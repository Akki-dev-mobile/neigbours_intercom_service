import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:meta/meta.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:intl/intl.dart';

part 'visitor_log_event.dart';
part 'visitor_log_state.dart';

class VisitorLogBloc extends Bloc<VisitorLogEvent, VisitorLogState> {
  final VisitorLogUsecase visitorLogUseCase;
  VisitorLogBloc(this.visitorLogUseCase) : super(VisitorLogInitial()) {
    on<FetchVisitorLogEvent>(fetchVisitorLogEvent);
    on<CheckOutEvent>(checkOutEvent);
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
      final visitorLogs =
          await visitorLogUseCase.fetchCheckInVisitorLog(412, formattedDate);
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
        DateTime today = DateTime.now();
        FetchVisitorLogEvent( today);
      }else{
        emit(VisitorLogErrorState('Something went wrong'));
      }
    } catch (error) {
      emit(VisitorLogErrorState(error.toString()));
    }
  }
}
