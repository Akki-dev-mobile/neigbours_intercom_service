import 'package:flutter_onegate/domain/entities/society/member_unit.dart';

class Building {
  int id;
  String name;
  List<MemberUnit> memberUnits;

  Building({
    required this.id,
    required this.name,
    required this.memberUnits,
  });

  factory Building.fromJson(Map<String, dynamic> json) {
    List<dynamic> unitList = json['member_units'];
    List<MemberUnit> units = unitList.map((unitJson) => MemberUnit.fromJson(unitJson)).toList();

    return Building(
      id: json['id'],
      name: json['name'],
      memberUnits: units,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'member_units': memberUnits.map((unit) => unit.toJson()).toList(),
    };
  }
}