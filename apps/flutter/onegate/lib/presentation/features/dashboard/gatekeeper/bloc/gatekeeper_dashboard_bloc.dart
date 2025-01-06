import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';
import 'package:onegate_client/onegate_client.dart';

part 'gatekeeper_dashboard_event.dart';
part 'gatekeeper_dashboard_state.dart';

class GatekeeperDashboardBloc
    extends Bloc<GatekeeperDashboardEvent, GatekeeperDashboardState> {
  final VisitorUsecase _visitorUsecase;
  final VisitorLogUsecase _visitorLogUsecase;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  GatekeeperDashboardBloc(this._visitorUsecase, this._visitorLogUsecase)
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
      final response = await _visitorUsecase.searchVisitor(event.mobileNumber);
      print("visitor --$response");
      emit(SaveSearchedVisitorState(visitor: response));

      emit(GatekeeperDashboardInitial());
    } catch (e) {
      print(e.toString());
      emit(
        GatekeeperDashboardErrorState(
          message: e.toString(),
        ),
      );
    }
  }

  FutureOr<void> onInputPutViewNextClickedEvent(
      InputPutViewNextClickedEvent event,
      Emitter<GatekeeperDashboardState> emit) async {
    emit(GatekeeperDashboardLoadingState());
    try {
      final purpose = await _visitorUsecase.fetchPurposeCategory();
      emit(GatekeeperDashboardInitial());
      //emit(InputPutViewNextClickedState());
      emit(OpenPurposeDialogState(purposeCategories: purpose));
    } catch (e) {
      print(e.toString());
      final purpose = await _visitorUsecase.fetchPurposeCategory();
      emit(OpenPurposeDialogState(purposeCategories: purpose));
      emit(
        GatekeeperDashboardErrorState(
          message: e.toString(),
        ),
      );
    }
  }

  FutureOr<void> onPurposeNextButtonClickedEvent(
      PurposeNextButtonClickedEvent event,
      Emitter<GatekeeperDashboardState> emit) async {
    emit(GatekeeperDashboardLoadingState());
    try {
      emit(NavigateToVisitorDetailsState(
        event.purpose,
        event.mobile,
        visitor: event.searchedVisitor,
      ));
    } catch (e) {
      print(e.toString());
      emit(
        GatekeeperDashboardErrorState(
          message: e.toString(),
        ),
      );
    }
  }

  FutureOr<void> onInitialEvent(GatekeeperDashboardInitialEvent event,
      Emitter<GatekeeperDashboardState> emit) async {
    try {
      emit(GatekeeperDashboardLoadingState());
      final List<VisitorLog>? checkedInVisitors =
          await _visitorLogUsecase.fetchCheckInVisitorLog(
              _preferenceUtils.getSelectedCompany()?.companyId ?? 0,
              DateTime.now().toString());
      final int inBook = checkedInVisitors!.length;

      final List<VisitorLog>? checkedOutVisitors =
          await _visitorLogUsecase.fetchCheckOutLogs(
              _preferenceUtils.getSelectedCompany()?.companyId ?? 0,
              DateTime.now().toString());
      final int outBook = checkedOutVisitors!.length;

      emit(GatekeeperDashboardSuccessState(inBook: inBook, outBook: outBook));
    } catch (e) {
      print(e.toString());
    }
  }

  FutureOr<void> onInAndOutButtonPressedEvent(
      GDInAndOutButtonPressedEvent event,
      Emitter<GatekeeperDashboardState> emit) async {
    emit(GDInAndOutButtonPressedState());
  }

  FutureOr<void> onVisitorsInButtonPressedEvent(
      GDVisitorsInButtonPressedEvent event,
      Emitter<GatekeeperDashboardState> emit) async {
    emit(GDVisitorsInButtonPressedState());
  }

  FutureOr<void> onVisitorsOutButtonPressedEvent(
      GDVisitorsOutButtonPressedEvent event,
      Emitter<GatekeeperDashboardState> emit) async {
    emit(GDVisitorsOutButtonPressedState());
  }
}
