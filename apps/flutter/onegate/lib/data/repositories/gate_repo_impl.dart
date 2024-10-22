import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/gate/gate2.dart';
import 'package:flutter_onegate/domain/mappers/gate/gate2_mapper.dart';
import 'package:flutter_onegate/domain/repositories/gate_repo.dart';

class GateRepositoryImpl implements GateRepository {
  final RemoteDataSource _remoteDataSource;

  GateRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Gate>?> gateList(int companyId) async {
    try {
      final response =
          await _remoteDataSource.fetchGates(companyId);
      final gateListResponse = GateMapper.fromJsonList(response);
      return gateListResponse;
    } catch (error) {
      return null; // Handle error or Gate failure
    }
  }
}
