import 'package:flutter_onegate/domain/entities/society/member.dart';

class MemberUnits {
  int id;
  int unitId;
  int socId;
  dynamic unitCategory;
  dynamic unitType;
  int socBuildingId;
  dynamic socBuildingName;
  dynamic socBuildingFloor;
  dynamic building;
  dynamic unitFlatNumber;
  int unitArea;
  dynamic unitOpenArea;
  dynamic effectiveDate;
  dynamic isAllotted;
  dynamic isOccupied;
  dynamic occupancyType;
  dynamic occupiedBy;
  dynamic vpa;
  int status;
  List<Member>? members;



  MemberUnits({
    required this.id,
    required this.unitId,
    required this.socId,
    required this.unitCategory,
    required this.unitType,
    required this.socBuildingId,
    required this.socBuildingName,
    required this.socBuildingFloor,
    required this.building,
    required this.unitFlatNumber,
    required this.unitArea,
    required this.unitOpenArea,
    required this.effectiveDate,
    required this.isAllotted,
    required this.isOccupied,
    required this.occupancyType,
    required this.occupiedBy,
    required this.vpa,
    required this.status,
  });

  factory MemberUnits.fromJson(Map<String, dynamic> json) {
    return MemberUnits(
      id: json['id'],
      unitId: json['unit_id'],
      socId: json['soc_id'],
      unitCategory: json['unit_category'],
      unitType: json['unit_type'],
      socBuildingId: json['soc_building_id'],
      socBuildingName: json['soc_building_name'],
      socBuildingFloor: json['soc_building_floor'],
      building: json['building'],
      unitFlatNumber: json['unit_flat_number'],
      unitArea: json['unit_area'],
      unitOpenArea: json['unit_open_area'],
      effectiveDate: json['effective_date'],
      isAllotted: json['is_allotted'],
      isOccupied: json['is_occupied'],
      occupancyType: json['occupancy_type'],
      occupiedBy: json['occupied_by'],
      vpa: json['vpa'],
      status: json['status'],
    );
  }
  static List<MemberUnits> fromJsonList(List<dynamic> jsonList) {
    return jsonList.map((json) => MemberUnits.fromJson(json)).toList();
  }
}
