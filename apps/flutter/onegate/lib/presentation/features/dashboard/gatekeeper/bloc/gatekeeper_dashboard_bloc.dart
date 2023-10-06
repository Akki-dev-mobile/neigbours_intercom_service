import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';

part 'gatekeeper_dashboard_event.dart';
part 'gatekeeper_dashboard_state.dart';

class GatekeeperDashboardBloc extends Bloc<GatekeeperDashboardEvent, GatekeeperDashboardState> {
  final VisitorUsecase _visitorUsecase;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  GatekeeperDashboardBloc(this._visitorUsecase) : super(GatekeeperDashboardInitial()) {
    on<GatekeeperDashboardEvent>((event, emit) {
    });
    on<GDOnMobileNumberEnteredEvent>(onMobileNumberEnteredEvent);
  }

  FutureOr<void> onMobileNumberEnteredEvent(GDOnMobileNumberEnteredEvent event, Emitter<GatekeeperDashboardState> emit) async{
    emit(GatekeeperDashboardLoadingState());
     try {
      final response = await _visitorUsecase.searchVisitor(event.mobileNumber);
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
}
