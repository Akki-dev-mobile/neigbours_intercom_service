
import 'package:flutter_onegate/domain/entities/staff/staff_entity.dart';

class StaffModel extends StaffEntity {
  StaffModel({
    required int id,
    required String buildingUnit,
    required String memberName,
  }) : super(id: id, buildingUnit: buildingUnit, memberName: memberName);

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: json['id'],
      buildingUnit: json['building_unit'],
      memberName: json['member_name'],
    );
  }
}