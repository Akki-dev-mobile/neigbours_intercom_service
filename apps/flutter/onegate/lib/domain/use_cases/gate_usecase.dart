import 'package:flutter_onegate/domain/entities/gate/gate_list_response.dart';
import 'package:flutter_onegate/domain/repositories/gate_repo.dart';

class GateUseCase {
  final GateRepository _repository;

  GateUseCase(this._repository);

  Future<GateListResponse?> gateList(int companyId, int userId) async{
    return await _repository.gateList(companyId, userId);
  }
}