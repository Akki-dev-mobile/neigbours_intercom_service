import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/admin_dash_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/auth_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/gate_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/society_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/visitor_repo_impl.dart';
import 'package:flutter_onegate/domain/repositories/admin_dash_repo.dart';
import 'package:flutter_onegate/domain/repositories/auth_repo.dart';
import 'package:flutter_onegate/domain/repositories/gate_repo.dart';
import 'package:flutter_onegate/domain/repositories/society_repo.dart';
import 'package:flutter_onegate/domain/repositories/visitor_log_repo.dart';
import 'package:flutter_onegate/domain/repositories/visitor_repo.dart';
import 'package:flutter_onegate/domain/use_cases/admin_dash_usecase.dart';
import 'package:flutter_onegate/domain/use_cases/auth_usecase.dart';
import 'package:flutter_onegate/domain/use_cases/gate_usecase.dart';
import 'package:flutter_onegate/domain/use_cases/society_usecase.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/presentation/features/auth/bloc/login_bloc.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/bloc/admin_dashboard_bloc.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/bloc/gatekeeper_dashboard_bloc.dart';

import 'package:flutter_onegate/presentation/features/gate_selection/bloc/gate_selection_bloc.dart';
import 'package:flutter_onegate/presentation/features/self_entry/bloc/self_entry_bloc.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/request_permission/bloc/request_permission_bloc.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/units_selection/bloc/units_selection_bloc.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_entry/bloc/visitor_in_entry_bloc.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/bloc/visitor_log_bloc.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_auth_service.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/api_client/authenticated_api_client.dart';
import 'package:flutter_onegate/services/api_service/onegate_api_service.dart';
import 'package:flutter_onegate/services/session_manager/user_session_manager.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';

import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GetIt locator = GetIt.instance;

setupLocator() {
  // Register Dio instance
  final dioInstance = Dio();
  locator.registerLazySingleton(() => dioInstance);

  // Register RemoteDataSource
  locator.registerLazySingleton(() => RemoteDataSource());

  // Register GateStorage
  locator.registerLazySingleton(() => GateStorage());

  // ✅ Register Enhanced Token Refresh Manager
  locator.registerLazySingleton<EnhancedTokenRefreshManager>(
    () => EnhancedTokenRefreshManager(),
  );

  // ✅ Register AuthService properly (now using AppAuth)
  locator.registerLazySingleton<AuthService>(
    () => AuthService(
      gateStorage: locator<GateStorage>(),
      remoteDataSource: locator<RemoteDataSource>(),
    ),
  );

  // ✅ Register new authentication and API services
  locator.registerLazySingleton<AuthenticatedApiClient>(
    () => AuthenticatedApiClient(),
  );

  locator.registerLazySingleton<OneGateApiService>(
    () => OneGateApiService(),
  );

  locator.registerLazySingleton<UserSessionManager>(
    () => UserSessionManager(),
  );

  // ✅ Register Enhanced Auth Service for debugging
  locator.registerLazySingleton<EnhancedAuthService>(
    () => EnhancedAuthService(
      gateStorage: locator<GateStorage>(),
      remoteDataSource: locator<RemoteDataSource>(),
    ),
  );

  // Register AuthenticationRepository
  locator.registerLazySingleton<AuthenticationRepository>(
    () => AuthenticationRepositoryImpl(locator<RemoteDataSource>()),
  );

  // Register LoginUseCase
  locator.registerLazySingleton(
      () => LoginUseCase(locator<AuthenticationRepository>()));

  // ✅ Register LoginBloc and pass AuthService
  locator.registerFactory(
      () => LoginBloc(locator<LoginUseCase>(), locator<GateUseCase>()));

  // Register GateRepository
  locator.registerLazySingleton<GateRepository>(
    () => GateRepositoryImpl(locator<RemoteDataSource>()),
  );

  // Register GateUseCase
  locator.registerLazySingleton(() => GateUseCase(locator<GateRepository>()));

  // Register GateBloc
  locator.registerFactory(() => GateSelectionBloc(locator<GateUseCase>()));

  // Register AdminDashboardRepository
  locator.registerLazySingleton<AdminDashboardRepository>(
    () => AdminDashboardRepositoryImpl(locator<RemoteDataSource>()),
  );

  // Register AdminDashboardUseCase
  locator.registerLazySingleton(
      () => AdminDashboardUseCase(locator<AdminDashboardRepository>()));

  // Register AdminDashboardBloc
  locator.registerFactory(() => AdminDashboardBloc(
      locator<AdminDashboardUseCase>(), locator<VisitorLogUsecase>()));

  // Register VisitorRepository
  locator.registerLazySingleton<VisitorRepository>(
    () => VisitorRepoImpl(locator<RemoteDataSource>()),
  );

  // Register VisitorUseCase
  locator.registerLazySingleton(
      () => VisitorUsecase(locator<VisitorRepository>()));

  // ✅ Register GatekeeperDashboardBloc
  locator.registerFactory(() => GatekeeperDashboardBloc(
      locator<VisitorUsecase>(), locator<VisitorLogUsecase>()));

  locator.registerFactory(() => VisitorInEntryBloc(
      locator<VisitorUsecase>(), locator<VisitorLogUsecase>()));

  locator.registerLazySingleton<SocietyRepository>(
    () => SocietyRepositoryImpl(locator<RemoteDataSource>()),
  );

  locator.registerLazySingleton(
      () => SocietyUseCase(locator<SocietyRepository>()));

  locator.registerFactory(() => UnitsSelectionBloc(locator<SocietyUseCase>()));

  locator.registerFactory(
      () => RequestPermissionBloc(locator<VisitorLogUsecase>()));

  locator.registerFactory(() => VisitorLogBloc(locator<VisitorLogUsecase>()));

  locator.registerLazySingleton<VisitorLogRepository>(
    () => VisitorLogRepositoryImpl(locator<RemoteDataSource>()),
  );

  locator.registerLazySingleton(
      () => VisitorLogUsecase(locator<VisitorLogRepository>()));

  locator.registerFactory(() => SelfEntryBloc(locator<VisitorUsecase>()));
}

setupDependencies() async {
  final preferencesInstance = await SharedPreferences.getInstance();
  final preferenceUtilsInstance = PreferenceUtils(preferencesInstance);
  locator.registerSingleton<PreferenceUtils>(preferenceUtilsInstance);
}
