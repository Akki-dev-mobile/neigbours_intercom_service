import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/auth_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/repositories/auth_repo.dart';
import 'package:flutter_onegate/domain/use_cases/auth_usecase.dart';
import 'package:flutter_onegate/presentation/features/auth/bloc/login_bloc.dart';

import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

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
}
