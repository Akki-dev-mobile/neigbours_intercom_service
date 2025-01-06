import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/gate/gate2.dart';
import 'package:flutter_onegate/domain/mappers/gate/gate2_mapper.dart';
import 'package:flutter_onegate/domain/repositories/gate_repo.dart';

class GateRepositoryImpl implements GateRepository {
  final RemoteDataSource _remoteDataSource;

  GateRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Gate>?> gateList(int companyId) async {
          print("Company IDDD GateRepositoryImpl companyId response: $companyId");

    try {
      final response =
          await _remoteDataSource.fetchGates();
      final gateListResponse = GateMapper.fromJsonList(response);
      print("Company IDDD GateRepositoryImpl response: $gateListResponse");
      return gateListResponse;
    } catch (error) {
      return null; // Handle error or Gate failure
    }
  }
}
