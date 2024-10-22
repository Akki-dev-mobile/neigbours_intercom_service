import 'package:flutter_onegate/domain/entities/society/building.dart';
import 'package:flutter_onegate/domain/entities/society/member.dart';
import 'package:flutter_onegate/domain/entities/society/member_unit.dart';

abstract class SocietyRepository {
  Future<List<Building>?> getBuildings(int companyId);
  Future<List<MemberUnits>?> getUnits(int companyId,int buildingId);
  Future<List<Member>?> getMembers(int companyId,int unitId);
}
