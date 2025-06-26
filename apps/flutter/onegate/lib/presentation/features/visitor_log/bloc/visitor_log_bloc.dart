import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:flutter/foundation.dart';

part 'visitor_log_event.dart';

part 'visitor_log_state.dart';

class VisitorLogBloc extends Bloc<VisitorLogEvent, VisitorLogState> {
  final VisitorLogUsecase visitorLogUseCase;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  final GateStorage _gateStorage = GateStorage();

  VisitorLogBloc(this.visitorLogUseCase) : super(VisitorLogInitial()) {
    on<FetchVisitorLogEvent>(fetchVisitorLogEvent);
    on<CheckOutEvent>(checkOutEvent);
    on<FetchCheckInLogEvent>(fetchCheckInLogEvent);
    on<FetchCheckOutLogEvent>(fetchCheckOutLogEvent);
    on<LoadMoreVisitorLogsEvent>(loadMoreVisitorLogsEvent);
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

      // Get company ID using the same method as remote data source
      final societyId = await _gateStorage.getSocietyId();
      final companyId = int.tryParse(societyId ?? '0') ?? 0;

      final visitorLogs = await visitorLogUseCase.fetchAllLogs(
        companyId,
        formattedDate,
        currentPage: event.currentPage,
        perPage: event.perPage,
        searchQuery: event.searchQuery,
      );

      emit(VisitorLogSuccessState(
        visitorLogs,
        currentPage: event.currentPage,
        hasMoreData: visitorLogs != null && visitorLogs.length >= event.perPage,
      ));
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

          // Get company ID using the same method as remote data source
          final societyId = await _gateStorage.getSocietyId();
          final companyId = int.tryParse(societyId ?? '0') ?? 0;

          final visitorLogs =
              await visitorLogUseCase.fetchAllLogs(companyId, formattedDate);

          // Emit success state with updated logs
          emit(VisitorLogSuccessState(
            visitorLogs,
            currentPage: 1,
            hasMoreData: visitorLogs != null && visitorLogs.length >= 10,
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
      debugPrint("🔥 [BLOC] fetchCheckInLogEvent started");
      emit(VisitorLogLoadingState());
      DateTime today = DateTime.now();

      // Get today's date in the desired format (yyyy-MM-dd)
      String formattedDate = getFormattedDate(today);

      // Get company ID using the same method as remote data source
      final societyId = await _gateStorage.getSocietyId();
      final companyId = int.tryParse(societyId ?? '0') ?? 0;

      debugPrint("🔥 [BLOC] Using company ID from gateStorage: $companyId");
      debugPrint("🔥 [BLOC] Using formatted date: $formattedDate");

      final visitorLogs = await visitorLogUseCase.fetchCheckInVisitorLog(
        companyId,
        formattedDate,
        currentPage: event.currentPage,
        perPage: event.perPage,
        searchQuery: event.searchQuery,
      );

      debugPrint(
          "🔥 [BLOC] API call completed - received ${visitorLogs?.length ?? 0} logs");

      if (visitorLogs != null && visitorLogs.isNotEmpty) {
        debugPrint(
            "✅ [BLOC] Emitting VisitorLogSuccessState with ${visitorLogs.length} logs");
        emit(VisitorLogSuccessState(
          visitorLogs,
          currentPage: event.currentPage,
          hasMoreData: visitorLogs.length >= event.perPage,
        ));
      } else {
        debugPrint(
            "⚠️ [BLOC] No visitor logs returned - emitting success with empty list");
        emit(VisitorLogSuccessState(
          const [],
          currentPage: event.currentPage,
          hasMoreData: false,
        ));
      }
    } catch (error) {
      debugPrint("💥 [BLOC] Exception in fetchCheckInLogEvent: $error");
      debugPrint("💥 [BLOC] Error type: ${error.runtimeType}");
      emit(VisitorLogErrorState(error.toString()));
    }
  }

  FutureOr<void> fetchCheckOutLogEvent(
      FetchCheckOutLogEvent event, Emitter<VisitorLogState> emit) async {
    try {
      debugPrint("🔥 [BLOC] fetchCheckOutLogEvent started");
      emit(VisitorLogLoadingState());
      DateTime today = DateTime.now();

      // Get today's date in the desired format (yyyy-MM-dd)
      String formattedDate = getFormattedDate(today);

      // Get company ID using the same method as remote data source
      final societyId = await _gateStorage.getSocietyId();
      final companyId = int.tryParse(societyId ?? '0') ?? 0;

      debugPrint("🔥 [BLOC] Using company ID from gateStorage: $companyId");
      debugPrint("🔥 [BLOC] Using formatted date: $formattedDate");

      final visitorLogs = await visitorLogUseCase.fetchCheckOutLogs(
        companyId,
        formattedDate,
        currentPage: event.currentPage,
        perPage: event.perPage,
        searchQuery: event.searchQuery,
      );

      debugPrint(
          "🔥 [BLOC] CheckOut API call completed - received ${visitorLogs?.length ?? 0} logs");

      if (visitorLogs != null && visitorLogs.isNotEmpty) {
        debugPrint(
            "✅ [BLOC] Emitting VisitorLogSuccessState with ${visitorLogs.length} checked-out logs");
        emit(VisitorLogSuccessState(
          visitorLogs,
          currentPage: event.currentPage,
          hasMoreData: visitorLogs.length >=
              event.perPage, // Enable pagination for visitor-out
        ));
      } else {
        debugPrint(
            "⚠️ [BLOC] No checked-out visitor logs returned - emitting success with empty list");
        emit(VisitorLogSuccessState(
          const [],
          currentPage: event.currentPage,
          hasMoreData: false,
        ));
      }
    } catch (error) {
      debugPrint("💥 [BLOC] Exception in fetchCheckOutLogEvent: $error");
      emit(VisitorLogErrorState(error.toString()));
    }
  }

  FutureOr<void> loadMoreVisitorLogsEvent(
      LoadMoreVisitorLogsEvent event, Emitter<VisitorLogState> emit) async {
    try {
      debugPrint(
          "🔥 [BLOC] loadMoreVisitorLogsEvent started - page ${event.currentPage}");

      // Get current state to preserve existing data
      final currentState = state;
      if (currentState is! VisitorLogSuccessState) {
        debugPrint(
            "❌ [BLOC] Cannot load more - current state is not success state");
        return;
      }

      emit(VisitorLogLoadingMoreState());

      DateTime today = DateTime.now();
      String formattedDate = getFormattedDate(today);

      // Get company ID using the same method as remote data source
      final societyId = await _gateStorage.getSocietyId();
      final companyId = int.tryParse(societyId ?? '0') ?? 0;

      debugPrint(
          "🔥 [BLOC] Loading more logs - page ${event.currentPage}, companyId: $companyId");

      // Fetch new page data based on filter type
      List<VisitorLog>? newVisitorLogs;
      switch (event.filterType) {
        case "check_in":
          newVisitorLogs = await visitorLogUseCase.fetchCheckInVisitorLog(
            companyId,
            formattedDate,
            currentPage: event.currentPage,
            perPage: event.perPage,
          );
          break;
        case "check_out":
          newVisitorLogs = await visitorLogUseCase.fetchCheckOutLogs(
            companyId,
            formattedDate,
            currentPage: event.currentPage,
            perPage: event.perPage,
          );
          break;
        default: // "all"
          newVisitorLogs = await visitorLogUseCase.fetchAllLogs(
            companyId,
            formattedDate,
            currentPage: event.currentPage,
            perPage: event.perPage,
          );
      }

      if (newVisitorLogs != null && newVisitorLogs.isNotEmpty) {
        // Combine existing logs with new logs
        final allLogs = <VisitorLog>[
          ...(currentState.visitorLogs ?? <VisitorLog>[]),
          ...newVisitorLogs
        ];

        debugPrint(
            "🔥 [BLOC] LoadMore completed - total logs: ${allLogs.length}");

        emit(VisitorLogSuccessState(
          allLogs,
          currentPage: event.currentPage,
          hasMoreData: newVisitorLogs.length >=
              event.perPage, // Has more if we got full page
        ));
      } else {
        debugPrint("🔥 [BLOC] LoadMore - no more logs available");
        emit(VisitorLogSuccessState(
          currentState.visitorLogs,
          currentPage: currentState.currentPage,
          hasMoreData: false,
        ));
      }
    } catch (error) {
      debugPrint("💥 [BLOC] Exception in loadMoreVisitorLogsEvent: $error");
      emit(VisitorLogErrorState(error.toString()));
    }
  }
}
