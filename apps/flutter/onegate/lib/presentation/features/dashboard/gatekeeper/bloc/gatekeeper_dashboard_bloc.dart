import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/exceptions/visitor_exceptions.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
// import 'package:flutter_onegate/utils/shared_pref.dart';
// import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';

part 'gatekeeper_dashboard_event.dart';
part 'gatekeeper_dashboard_state.dart';

class GatekeeperDashboardBloc
    extends Bloc<GatekeeperDashboardEvent, GatekeeperDashboardState> {
  final VisitorUsecase _visitorUsecase;
  final VisitorLogUsecase visitorLogUsecase;
  // PreferenceUtils is available via GetIt if needed in future flows
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

      // Use V2 API to get counts instead of calling both individual methods
      // This avoids the conflict where both fetchCheckInLogs and fetchCheckOutLogs
      // are called simultaneously, causing only checked-out visitors to be shown
      final counts = await visitorLogUsecase.getVisitorCounts(
          int.parse(companyId.toString()), today.toString());

      final int inBook = counts['visitor_in'] ?? 0; // Checked-in visitors count
      final int outBook =
          counts['visitor_out'] ?? 0; // Checked-out visitors count

      emit(GatekeeperDashboardSuccessState(inBook: inBook, outBook: outBook));
    } catch (e) {
      // Log the error but still show dashboard with default counts
      print('⚠️ Error fetching visitor counts: $e');
      print('🔄 Showing dashboard with default counts');

      // Show dashboard with zeros instead of error state
      // This ensures the dashboard loads even if visitor counts fail
      emit(GatekeeperDashboardSuccessState(inBook: 0, outBook: 0));
    }
  }

  FutureOr<void> onInAndOutButtonPressedEvent(
      GDInAndOutButtonPressedEvent event,
      Emitter<GatekeeperDashboardState> emit) async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    // Emit loading state first
    emit(GDInAndOutLoadingState());

    // Wait for a short duration to show the loader
    await Future.delayed(const Duration(milliseconds: 1500));

    // Emit navigation state
    emit(GDInAndOutButtonPressedState());

    Future.delayed(
        const Duration(milliseconds: 500), () => _hasNavigated = false);
  }

  FutureOr<void> onVisitorsInButtonPressedEvent(
      GDVisitorsInButtonPressedEvent event,
      Emitter<GatekeeperDashboardState> emit) async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    // Emit loading state first
    emit(GDVisitorsInLoadingState());

    // Wait for a short duration to show the loader
    await Future.delayed(const Duration(milliseconds: 1500));

    // Emit navigation state
    emit(GDVisitorsInButtonPressedState());

    Future.delayed(
        const Duration(milliseconds: 500), () => _hasNavigated = false);
  }

  FutureOr<void> onVisitorsOutButtonPressedEvent(
      GDVisitorsOutButtonPressedEvent event,
      Emitter<GatekeeperDashboardState> emit) async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    // Emit loading state first
    emit(GDVisitorsOutLoadingState());

    // Wait for a short duration to show the loader
    await Future.delayed(const Duration(milliseconds: 1500));

    emit(GDVisitorsOutButtonPressedState());

    Future.delayed(
        const Duration(milliseconds: 500), () => _hasNavigated = false);
  }

  // Removed unused _emitDashboardSuccessState to avoid showing dashboard loader during navigation
}
