

import 'package:flutter_onegate/domain/entities/society/building.dart';
import 'package:flutter_onegate/domain/repositories/society_repo.dart';

class SocietyUseCase {
  final SocietyRepository _repository;

  SocietyUseCase(this._repository);

  Future<Building?> login(int companyId) async{
    return await _repository.getBuildings(companyId);
  }
}