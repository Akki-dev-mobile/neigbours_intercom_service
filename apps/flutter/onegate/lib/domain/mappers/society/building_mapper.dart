import 'package:flutter_onegate/domain/entities/society/building.dart';
import 'package:flutter_onegate/domain/entities/society/member_unit.dart';
import 'package:flutter_onegate/domain/mappers/society/member_unit_mapper.dart';

class BuildingMapper {
  static Building fromJson(Map<String, dynamic> json) {
    List<dynamic> unitList = json['member_units'];
    List<MemberUnit> units = unitList.map((unitJson) => MemberUnitMapper.fromJson(unitJson)).toList();

    return Building(
      id: json['id'],
      name: json['name'],
      memberUnits: units,
    );
  }

  static Map<String, dynamic> toJson(Building building) {
    return {
      'id': building.id,
      'name': building.name,
      'member_units': building.memberUnits.map((unit) => MemberUnitMapper.toJson(unit)).toList(),
    };
  }
}