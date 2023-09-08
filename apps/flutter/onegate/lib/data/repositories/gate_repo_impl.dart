import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/gate/gate_list_response.dart';
import 'package:flutter_onegate/domain/mappers/gate/gate_list_response_mapper.dart';
import 'package:flutter_onegate/domain/repositories/gate_repo.dart';

class GateRepositoryImpl implements GateRepository {
  final RemoteDataSource _remoteDataSource;

  GateRepositoryImpl(this._remoteDataSource);

  @override
  Future<GateListResponse?> gateList(
      int companyId, int userId) async {
    try {
      final response =
          await _remoteDataSource.fetchGatesData(companyId, userId);
      final gateListResponse = GateListResponseMapper.fromJson(response);
      return gateListResponse;
    } catch (error) {
      return null; // Handle error or Gate failure
    }
  }
}