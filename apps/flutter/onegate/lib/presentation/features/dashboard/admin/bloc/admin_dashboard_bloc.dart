import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/use_cases/admin_dash_usecase.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';

part 'admin_dashboard_event.dart';
part 'admin_dashboard_state.dart';

class AdminDashboardBloc
    extends Bloc<AdminDashboardEvent, AdminDashboardState> {
  final AdminDashboardUseCase _adminDashboardUseCase;
  final VisitorLogUsecase _visitorLogUsecase;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  final RemoteDataSource _remoteDataSource = RemoteDataSource();

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
      // Emit cached data first for instant load
      final prefs = await SharedPreferences.getInstance();
      final cachedInBook = prefs.getInt('cached_in_book');
      final cachedOutBook = prefs.getInt('cached_out_book');
      if (cachedInBook != null && cachedOutBook != null) {
        emit(AdminDashboardSuccessState(
            inBook: cachedInBook, outBook: cachedOutBook));
      } else {
        emit(AdminDashboardLoadingState());
      }

      // Fetch gate info once
      await _remoteDataSource.fetchAndUpdateGateInfo('admin_dashboard');

      final companyId = _preferenceUtils.getSelectedCompany()?.companyId ?? 0;
      final today = DateTime.now().toString();

      final results = await Future.wait([
        _visitorLogUsecase.fetchCheckInVisitorLog(companyId, today),
        _visitorLogUsecase.fetchCheckOutLogs(companyId, today)
      ]);

      final checkedInVisitors = results[0];
      final checkedOutVisitors = results[1];

      final int inBook = checkedInVisitors?.length ?? 0;
      final int outBook = checkedOutVisitors?.length ?? 0;

      // Cache the new data
      await prefs.setInt('cached_in_book', inBook);
      await prefs.setInt('cached_out_book', outBook);

      emit(AdminDashboardSuccessState(inBook: inBook, outBook: outBook));
    } catch (e) {
      print(e.toString());
      emit(AdminDashboardErrorState(error: e.toString()));
    }
  }
}
