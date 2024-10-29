import 'package:flutter_onegate/domain/entities/society/member.dart';

class MemberUnits {
  int? id;
  int? unitId;
  int? socId;
  dynamic unitCategory;
  dynamic unitType;
  int? socBuildingId;
  dynamic socBuildingName;
  dynamic socBuildingFloor;
  dynamic building;
  dynamic unitFlatNumber;
  int? unitArea;
  dynamic unitOpenArea;
  dynamic effectiveDate;
  dynamic isAllotted;
  dynamic isOccupied;
  dynamic occupancyType;
  dynamic occupiedBy;
  dynamic vpa;
  int? status;
  List<Member>? members;

  MemberUnits({
    this.id,
    this.unitId,
    this.socId,
    this.unitCategory,
    this.unitType,
    this.socBuildingId,
    this.socBuildingName,
    this.socBuildingFloor,
    this.building,
    this.unitFlatNumber,
    this.unitArea,
    this.unitOpenArea,
    this.effectiveDate,
    this.isAllotted,
    this.isOccupied,
    this.occupancyType,
    this.occupiedBy,
    this.vpa,
    this.status,
    this.members,
  });

  // Helper function to parse integers safely from dynamic types
  static int? parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory MemberUnits.fromJson(Map<String, dynamic> json) {
    return MemberUnits(
      id: parseInt(json['id']),
      unitId: parseInt(json['unit_id']),
      socId: parseInt(json['soc_id']),
      unitCategory: json['unit_category'],
      unitType: json['unit_type'],
      socBuildingId: parseInt(json['soc_building_id']),
      socBuildingName: json['soc_building_name'],
      socBuildingFloor: json['soc_building_floor'],
      building: json['building'],
      unitFlatNumber: json['unit_flat_number'],
      unitArea: parseInt(json['unit_area']),
      unitOpenArea: json['unit_open_area'],
      effectiveDate: json['effective_date'],
      isAllotted: json['is_allotted'],
      isOccupied: json['is_occupied'],
      occupancyType: json['occupancy_type'],
      occupiedBy: json['occupied_by'],
      vpa: json['vpa'],
      status: parseInt(json['status']),
      members: (json['members'] as List<dynamic>?)
          ?.map((memberJson) => Member.fromJson(memberJson))
          .toList(),
    );
  }

  static List<MemberUnits> fromJsonList(List<dynamic> jsonList) {
    return jsonList
        .map((json) => MemberUnits.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
