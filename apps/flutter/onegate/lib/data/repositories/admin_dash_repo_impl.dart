import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/repositories/admin_dash_repo.dart';

class AdminDashboardRepositoryImpl implements AdminDashboardRepository {
  final RemoteDataSource _remoteDataSource;

  AdminDashboardRepositoryImpl(this._remoteDataSource);

  
}