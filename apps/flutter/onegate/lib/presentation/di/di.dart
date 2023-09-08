import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/auth_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/gate_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/repositories/auth_repo.dart';
import 'package:flutter_onegate/domain/repositories/gate_repo.dart';
import 'package:flutter_onegate/domain/use_cases/auth_usecase.dart';
import 'package:flutter_onegate/domain/use_cases/gate_usecase.dart';
import 'package:flutter_onegate/presentation/features/auth/bloc/login_bloc.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/bloc/gate_selection_bloc.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';

import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // Register Dio instance
  final Dio dio = Dio(); // You can configure Dio here
  locator.registerLazySingleton(() => dioInstance);

  // Register RemoteDataSource
  locator.registerLazySingleton(() => RemoteDataSource(locator<Dio>()));

  // Register AuthenticationRepository
  locator.registerLazySingleton<AuthenticationRepository>(
    () => AuthenticationRepositoryImpl(locator<RemoteDataSource>()),
  );

  // Register LoginUseCase
  locator.registerLazySingleton(() => LoginUseCase(locator<AuthenticationRepository>()));

  // Register LoginBloc
  locator.registerFactory(() => LoginBloc(locator<LoginUseCase>()));

  // Register GateRepository
  locator.registerLazySingleton<GateRepository>(
    () => GateRepositoryImpl(locator<RemoteDataSource>()),
  );

  // Register GateUseCase
  locator.registerLazySingleton(() => GateUseCase(locator<GateRepository>()));

  // Register GateBloc
  locator.registerFactory(() => GateSelectionBloc(locator<GateUseCase>()));
}

 void setupDependencies() async{
  final preferencesInstance = await SharedPreferences.getInstance();
  final preferenceUtilsInstance = PreferenceUtils(preferencesInstance);
  locator.registerSingleton<PreferenceUtils>(preferenceUtilsInstance);
}
