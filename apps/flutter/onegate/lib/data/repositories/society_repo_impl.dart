import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/society/building.dart';
import 'package:flutter_onegate/domain/repositories/society_repo.dart';

class SocietyRepositoryImpl implements SocietyRepository {
  final RemoteDataSource _remoteDataSource;

  SocietyRepositoryImpl(this._remoteDataSource);

  @override
  Future<Building?> getBuildings(int companyId) async {
    return null;
  
    // try {
    //   final response = await _remoteDataSource.fetchBuildingsData(companyId);
    //   final buildingResponse = BuildingMapper.fromJson(response);
    //   return buildingResponse;
    // } catch (error) {
    //   return null; // Handle error or authentication failure
    // }
  }
}
