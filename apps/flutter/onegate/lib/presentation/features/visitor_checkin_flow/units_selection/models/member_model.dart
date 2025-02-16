class MemberModel {
  final String name;
  final String unitId;
  final int memberId;
  final String buildingUnit;
  final String? mobileNumber;

  MemberModel({
    required this.name,
    required this.unitId,
    required this.memberId,
    required this.buildingUnit,
    this.mobileNumber,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'unit_id': unitId,
        'member_ids': memberId,
        'building_unit': buildingUnit,
        'mobile_number': mobileNumber,
      };

  factory MemberModel.fromJson(Map<String, dynamic> json) => MemberModel(
        name: json['name'],
        unitId: json['unit_id'].toString(),
        memberId: json['member_ids'],
        buildingUnit: json['building_unit'],
        mobileNumber: json['mobile_number'],
      );
}