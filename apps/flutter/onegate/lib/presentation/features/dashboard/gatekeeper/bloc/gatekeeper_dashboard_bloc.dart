import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';
import 'package:flutter_onegate/domain/exceptions/visitor_exceptions.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';

part 'gatekeeper_dashboard_event.dart';
part 'gatekeeper_dashboard_state.dart';

class GatekeeperDashboardBloc
    extends Bloc<GatekeeperDashboardEvent, GatekeeperDashboardState> {
  final VisitorUsecase _visitorUsecase;
  final VisitorLogUsecase visitorLogUsecase;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  bool _hasNavigated = false;

  GatekeeperDashboardBloc(this._visitorUsecase, this.visitorLogUsecase)
      : super(GatekeeperDashboardInitial()) {
    on<GatekeeperDashboardInitialEvent>(onInitialEvent);
    on<GDOnMobileNumberEnteredEvent>(onMobileNumberEnteredEvent);
    on<InputPutViewNextClickedEvent>(onInputPutViewNextClickedEvent);
    on<PurposeNextButtonClickedEvent>(onPurposeNextButtonClickedEvent);
    on<GDInAndOutButtonPressedEvent>(onInAndOutButtonPressedEvent);
    on<GDVisitorsInButtonPressedEvent>(onVisitorsInButtonPressedEvent);
    on<GDVisitorsOutButtonPressedEvent>(onVisitorsOutButtonPressedEvent);
  }

  FutureOr<void> onMobileNumberEnteredEvent(GDOnMobileNumberEnteredEvent event,
      Emitter<GatekeeperDashboardState> emit) async {
    emit(GatekeeperDashboardLoadingState());
    try {
      print(
          "🔄 Bloc: Starting searchVisitor for mobile: ${event.mobileNumber}");
      final response = await _visitorUsecase.searchVisitor(event.mobileNumber);
      print("✅ Bloc: searchVisitor completed successfully");
      emit(SaveSearchedVisitorState(visitor: response));
    } on VisitorAlreadyCheckedInException catch (e) {
      // Handle specific case where visitor is already checked in within 3 minutes
      print("🚨 Bloc: Caught VisitorAlreadyCheckedInException: ${e.message}");
      emit(VisitorAlreadyCheckedInErrorState(message: e.message));
    } on VisitorApiException catch (e) {
      // Handle general API errors with non-200 status codes
      print(
          "🚨 Bloc: Caught VisitorApiException: ${e.message}, Status: ${e.statusCode}");
      emit(VisitorApiErrorState(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      print("🚨 Bloc: Caught general exception: $e");
      emit(GatekeeperDashboardErrorState(message: e.toString()));
    }
  }

  FutureOr<void> onInputPutViewNextClickedEvent(
      InputPutViewNextClickedEvent event,
      Emitter<GatekeeperDashboardState> emit) async {
    emit(GatekeeperDashboardLoadingState());
    try {
      final purpose = await _visitorUsecase.fetchPurposeCategory();
      emit(OpenPurposeDialogState(purposeCategories: purpose));
    } catch (e) {
      emit(GatekeeperDashboardErrorState(message: e.toString()));
    }
  }

  FutureOr<void> onPurposeNextButtonClickedEvent(
      PurposeNextButtonClickedEvent event,
      Emitter<GatekeeperDashboardState> emit) async {
    emit(GatekeeperDashboardLoadingState());
    emit(NavigateToVisitorDetailsState(
      event.purpose,
      event.mobile,
      visitor: event.searchedVisitor,
    ));
  }

  FutureOr<void> onInitialEvent(GatekeeperDashboardInitialEvent event,
      Emitter<GatekeeperDashboardState> emit) async {
    try {
      emit(GatekeeperDashboardLoadingState());

      final gateStorage = GateStorage();
      final companyId = await gateStorage.getSocietyId();
      final today = DateTime.now();

      final List<VisitorLog>? allCheckedInVisitors =
          await visitorLogUsecase.fetchCheckInVisitorLog(
              int.parse(companyId.toString()), today.toString());
      final List<VisitorLog> todaysCheckedInVisitors =
          allCheckedInVisitors?.where((visitor) {
                final DateTime checkInDate = DateTime.parse(visitor
                    .visitor_check_in
                    .toString()); // Replace 'timestamp' with actual field
                return checkInDate.year == today.year &&
                    checkInDate.month == today.month &&
                    checkInDate.day == today.day;
              }).toList() ??
              [];
      final int inBook = todaysCheckedInVisitors.length;

      final List<VisitorLog>? allCheckedOutVisitors = await visitorLogUsecase
          .fetchCheckOutLogs(int.parse(companyId.toString()), today.toString());
      final List<VisitorLog> todaysCheckedOutVisitors =
          allCheckedOutVisitors?.where((visitor) {
                final DateTime checkOutDate = DateTime.parse(visitor
                    .visitor_check_out
                    .toString()); // Replace 'timestamp' with actual field
                return checkOutDate.year == today.year &&
                    checkOutDate.month == today.month &&
                    checkOutDate.day == today.day;
              }).toList() ??
              [];
      final int outBook = todaysCheckedOutVisitors.length;

      emit(GatekeeperDashboardSuccessState(inBook: inBook, outBook: outBook));
    } catch (e) {
      emit(GatekeeperDashboardErrorState(message: e.toString()));
    }
  }

  FutureOr<void> onInAndOutButtonPressedEvent(
      GDInAndOutButtonPressedEvent event,
      Emitter<GatekeeperDashboardState> emit) async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    // Emit navigation state
    emit(GDInAndOutButtonPressedState());

    // Fetch the updated data for the dashboard
    await _emitDashboardSuccessState(emit);

    Future.delayed(
        const Duration(milliseconds: 500), () => _hasNavigated = false);
  }

  FutureOr<void> onVisitorsInButtonPressedEvent(
      GDVisitorsInButtonPressedEvent event,
      Emitter<GatekeeperDashboardState> emit) async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    // Emit navigation state
    emit(GDVisitorsInButtonPressedState());

    // Fetch the updated data for the dashboard
    await _emitDashboardSuccessState(emit);

    Future.delayed(
        const Duration(milliseconds: 500), () => _hasNavigated = false);
  }

  FutureOr<void> onVisitorsOutButtonPressedEvent(
      GDVisitorsOutButtonPressedEvent event,
      Emitter<GatekeeperDashboardState> emit) async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    emit(GDVisitorsOutButtonPressedState());

    await _emitDashboardSuccessState(emit);

    Future.delayed(
        const Duration(milliseconds: 500), () => _hasNavigated = false);
  }

  Future<void> _emitDashboardSuccessState(
      Emitter<GatekeeperDashboardState> emit) async {
    try {
      emit(GatekeeperDashboardLoadingState());

      final gateStorage = GateStorage();
      final companyId = await gateStorage.getSocietyId();
      final today = DateTime.now();

      final List<VisitorLog>? allCheckedInVisitors =
          await visitorLogUsecase.fetchCheckInVisitorLog(
              int.parse(companyId.toString()), today.toString());
      final List<VisitorLog> todaysCheckedInVisitors =
          allCheckedInVisitors?.where((visitor) {
                final DateTime checkInDate =
                    DateTime.parse(visitor.visitor_check_in.toString());
                return checkInDate.year == today.year &&
                    checkInDate.month == today.month &&
                    checkInDate.day == today.day;
              }).toList() ??
              [];
      final int inBook = todaysCheckedInVisitors.length;

      final List<VisitorLog>? allCheckedOutVisitors = await visitorLogUsecase
          .fetchCheckOutLogs(int.parse(companyId.toString()), today.toString());
      final List<VisitorLog> todaysCheckedOutVisitors =
          allCheckedOutVisitors?.where((visitor) {
                final DateTime checkOutDate =
                    DateTime.parse(visitor.visitor_check_out.toString());
                return checkOutDate.year == today.year &&
                    checkOutDate.month == today.month &&
                    checkOutDate.day == today.day;
              }).toList() ??
              [];
      final int outBook = todaysCheckedOutVisitors.length;

      emit(GatekeeperDashboardSuccessState(inBook: inBook, outBook: outBook));
    } catch (e) {
      emit(GatekeeperDashboardErrorState(message: e.toString()));
    }
  }
}
