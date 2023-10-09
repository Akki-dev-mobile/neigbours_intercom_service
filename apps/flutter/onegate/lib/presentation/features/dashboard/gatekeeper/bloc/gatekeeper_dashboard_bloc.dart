import 'dart:async';

import 'package:bloc/bloc.dart';
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
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  GatekeeperDashboardBloc(this._visitorUsecase)
      : super(GatekeeperDashboardInitial()) {
    on<GatekeeperDashboardEvent>((event, emit) {});
    on<GDOnMobileNumberEnteredEvent>(onMobileNumberEnteredEvent);
    on<InputPutViewNextClickedEvent>(onInputPutViewNextClickedEvent);
  }

  FutureOr<void> onMobileNumberEnteredEvent(GDOnMobileNumberEnteredEvent event,
      Emitter<GatekeeperDashboardState> emit) async {
    emit(GatekeeperDashboardLoadingState());
    try {
      final response = await _visitorUsecase.searchVisitor(event.mobileNumber);
      if (response != null) {
        emit(SaveSearchedVisitorState(visitor: response));
      }
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
}
