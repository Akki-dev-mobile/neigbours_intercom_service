import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

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

      int currentPage = 1;
      int perPage = 40;

      final visitorLogs = await visitorLogUseCase.fetchAllLogs(
        _preferenceUtils.getSelectedCompany()?.companyId ?? 0,
        DateFormat('yyyy-MM-dd').format(event.date),
        currentPage: currentPage,
        perPage: perPage,
      );

      bool hasMoreData = visitorLogs?.length == perPage;

      emit(VisitorLogSuccessState(
          visitorLogs: visitorLogs,
          hasMoreData: hasMoreData,
          currentPage: currentPage));
    } catch (error) {
      emit(VisitorLogErrorState(error.toString()));
    }
  }

  FutureOr<void> checkOutEvent(
      CheckOutEvent event, Emitter<VisitorLogState> emit) async {
    try {
      // Emit loading state
      emit(VisitorLogLoadingState());

      // Perform the checkout operation
      final response = await visitorLogUseCase.checkOut(event.visitorLog);

      if (response) {
        event.visitorLog.visitor_check_out = DateTime.now();
        event.visitorLog.is_checked_out = true;

        if (event.screenType == 'Visitor In') {
          emit(VisitorCheckInLogSuccessState());
        } else if (event.screenType == "In Out Book") {
          DateTime today = DateTime.now();
          String formattedDate = getFormattedDate(today);
          final visitorLogs = await visitorLogUseCase.fetchAllLogs(
              _preferenceUtils.getSelectedCompany()?.companyId ?? 0,
              formattedDate);

          // Emit success state with updated logs
          emit(VisitorLogSuccessState(
            visitorLogs: visitorLogs,
          ));
        } else {
          emit(VisitorCheckOutLogSuccessState());
        }
      } else {
        // Handle failure
        emit(VisitorLogErrorState('Something went wrong'));
      }
    } catch (error) {
      // Emit error state on exception
      emit(VisitorLogErrorState(error.toString()));
    }
  }

  FutureOr<void> fetchCheckInLogEvent(
      FetchCheckInLogEvent event, Emitter<VisitorLogState> emit) async {
    try {
      emit(VisitorLogLoadingState());

      final visitorLogs = await visitorLogUseCase.fetchCheckInVisitorLog(
        _preferenceUtils.getSelectedCompany()?.companyId ?? 0,
        DateFormat('yyyy-MM-dd').format(event.date),
        currentPage: event.currentPage,
        perPage: event.perPage,
      );

      final hasMoreData = visitorLogs?.length == event.perPage;
      emit(VisitorLogSuccessState(
          visitorLogs: visitorLogs, hasMoreData: hasMoreData));
    } catch (error) {
      emit(VisitorLogErrorState(error.toString()));
    }
  }

  FutureOr<void> fetchCheckOutLogEvent(
      FetchCheckOutLogEvent event, Emitter<VisitorLogState> emit) async {
    try {
      emit(VisitorLogLoadingState());

      final visitorLogs = await visitorLogUseCase.fetchCheckOutLogs(
        _preferenceUtils.getSelectedCompany()?.companyId ?? 0,
        DateFormat('yyyy-MM-dd').format(event.date),
        currentPage: event.currentPage,
        perPage: event.perPage,
      );

      final hasMoreData = visitorLogs?.length == event.perPage;
      emit(VisitorLogSuccessState(
          visitorLogs: visitorLogs, hasMoreData: hasMoreData));
    } catch (error) {
      emit(VisitorLogErrorState(error.toString()));
    }
  }

  FutureOr<void> loadMoreVisitorLogsEvent(
      LoadMoreVisitorLogsEvent event, Emitter<VisitorLogState> emit) async {
    final currentState = state;
    if (currentState is VisitorLogSuccessState && currentState.hasMoreData!) {
      emit(VisitorLogLoadingMoreState());

      try {
        int nextPage = currentState.currentPage! + 1;
        int perPage = 20;

        final moreLogs = await visitorLogUseCase.fetchAllLogs(
          _preferenceUtils.getSelectedCompany()?.companyId ?? 0,
          DateFormat('yyyy-MM-dd').format(DateTime.now()),
          currentPage: nextPage,
          perPage: perPage,
        );

        if (moreLogs!.isEmpty) {
          emit(VisitorLogSuccessState(
            visitorLogs: currentState.visitorLogs!,
            hasMoreData: false, // No more data
            currentPage: nextPage,
          ));
        } else {
          List<VisitorLog> updatedLogs = List.from(currentState.visitorLogs!)
            ..addAll(moreLogs!);

          emit(VisitorLogSuccessState(
              visitorLogs: updatedLogs,
              hasMoreData: moreLogs.length == perPage,
              currentPage: nextPage));
        }
      } catch (error) {
        emit(VisitorLogErrorState(error.toString()));
      }
    }
  }
}
