import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/use_cases/admin_dash_usecase.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';

part 'admin_dashboard_event.dart';
part 'admin_dashboard_state.dart';

class AdminDashboardBloc extends Bloc<AdminDashboardEvent, AdminDashboardState> {
  final AdminDashboardUseCase _adminDashboardUseCase;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  AdminDashboardBloc(this._adminDashboardUseCase) : super(AdminDashboardInitial()) {
    on<AdminDashboardEvent>((event, emit) {
    });
    on<AdminDashboardSettingsPressedEvent>(adminDashboardSettingsPressedEvent);
  }

  FutureOr<void> adminDashboardSettingsPressedEvent(AdminDashboardSettingsPressedEvent event, Emitter<AdminDashboardState> emit) {
    
  }
}
