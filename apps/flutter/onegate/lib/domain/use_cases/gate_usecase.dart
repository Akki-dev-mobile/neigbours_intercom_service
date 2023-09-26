import 'package:flutter_onegate/domain/entities/gate/gate2.dart';
import 'package:flutter_onegate/domain/repositories/gate_repo.dart';

class GateUseCase {
  final GateRepository _repository;

  GateUseCase(this._repository);

  Future<List<Gate>?> gateList(int companyId) async{
    return await _repository.gateList(companyId);
  }
}