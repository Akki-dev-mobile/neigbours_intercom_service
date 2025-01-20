import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/use_cases/admin_dash_usecase.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'admin_dashboard_event.dart';
part 'admin_dashboard_state.dart';

class AdminDashboardBloc
    extends Bloc<AdminDashboardEvent, AdminDashboardState> {
  final AdminDashboardUseCase _adminDashboardUseCase;
  final VisitorLogUsecase _visitorLogUsecase;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();

  AdminDashboardBloc(this._adminDashboardUseCase, this._visitorLogUsecase)
      : super(AdminDashboardInitial()) {
    on<AdminDashboardInitialEvent>(adminDashboardInitial);
    on<AdminDashboardSettingsPressedEvent>(adminDashboardSettingsPressedEvent);
  }

  FutureOr<void> adminDashboardSettingsPressedEvent(
      AdminDashboardSettingsPressedEvent event,
      Emitter<AdminDashboardState> emit) {}

  FutureOr<void> adminDashboardInitial(AdminDashboardInitialEvent event,
      Emitter<AdminDashboardState> emit) async {
    try {
      emit(AdminDashboardLoadingState());
      final List<VisitorLog>? checkedInVisitors =
          await _visitorLogUsecase.fetchCheckInVisitorLog(
        _preferenceUtils.getSelectedCompany()?.companyId ?? 0,
        DateTime.now().toString(),
        // DateTime.now().subtract(Duration(days: 1)).toString(),
      );
   //    final prefs = await SharedPreferences.getInstance();
   // final inBook=  await  prefs.getInt('todayLogsCount');
   //    final outBook=  await  prefs.getInt('todayChLogsCount');
      final int inBook = checkedInVisitors?.length ?? 0;

      final List<VisitorLog>? checkedOutVisitors =
      await _visitorLogUsecase.fetchCheckOutLogs(
          _preferenceUtils.getSelectedCompany()?.companyId ?? 0,
          DateTime.now().toString());
      final int outBook = checkedOutVisitors?.length ?? 0;
      emit(AdminDashboardSuccessState(inBook: inBook, outBook: outBook));
    } catch (e) {
      print(e.toString());
    }
  }
}
