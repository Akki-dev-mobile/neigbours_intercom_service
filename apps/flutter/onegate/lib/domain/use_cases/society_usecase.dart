

import 'package:flutter_onegate/domain/entities/society/building.dart';
import 'package:flutter_onegate/domain/entities/society/member.dart';
import 'package:flutter_onegate/domain/entities/society/member_unit.dart';
import 'package:flutter_onegate/domain/repositories/society_repo.dart';

class SocietyUseCase {
  final SocietyRepository _repository;

  SocietyUseCase(this._repository);

  Future<List<Building>?> getBuildings(int companyId) async{
    return await _repository.getBuildings(companyId);
  }

  Future<List<MemberUnits>?> getUnits(int companyId,int buildingId) async{
    return await _repository.getUnits(companyId, buildingId);
  }

  Future<List<Member>?> getMembers(int companyId,int unitId) async{
    return await _repository.getMembers(companyId, unitId);
  }
}