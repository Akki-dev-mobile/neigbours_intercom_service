import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/society/building.dart';
import 'package:flutter_onegate/domain/entities/society/member.dart';
import 'package:flutter_onegate/domain/entities/society/member_unit.dart';
import 'package:flutter_onegate/domain/repositories/society_repo.dart';

class SocietyRepositoryImpl implements SocietyRepository {
  final RemoteDataSource _remoteDataSource;

  SocietyRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Building>?> getBuildings(int companyId) async {
    try {
      final response = await _remoteDataSource.getBuilding(companyId);
      final buildingList = Building.fromJsonList(response);
      return buildingList;
    } catch (error) {
      print(error.toString());
      return null;
    }
  }

  @override
  Future<List<MemberUnits>?> getUnits(int? companyId, int? buildingId) async {
    try {
      final response = await _remoteDataSource.getMemberUnit(
          companyId ?? 412, buildingId ?? 1);
      final unitList = MemberUnits.fromJsonList(response);
      return unitList;
    } catch (error) {
      print(error.toString());
      return null;
    }
  }

  @override
  Future<List<Member>?> getMembers(int companyId, int unitId) async {
    try {
      final response = await _remoteDataSource.getMember(companyId, unitId);
      final memberList = Member.fromJsonList(response);
      return memberList;
    } catch (error) {
      print(error.toString());
      return null;
    }
  }
}
