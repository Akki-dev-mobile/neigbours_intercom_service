class Member {
  int id;
  dynamic memberId;
  int fkUnitId;
  dynamic salute;
  dynamic memberName;
  dynamic memberEmailId;
  dynamic memberMobileNumber;
  dynamic memberEffectiveDate;
  dynamic memberTypeName;
  dynamic memberIntercom;
  dynamic memberStatus;
  dynamic status;
  dynamic socBuildingName;
  dynamic unitFlatNumber;
  dynamic buildingUnit;
  dynamic approved;

  Member({
    required this.id,
    required this.memberId,
    required this.fkUnitId,
    required this.salute,
    required this.memberName,
    required this.memberEmailId,
    required this.memberMobileNumber,
    required this.memberEffectiveDate,
    required this.memberTypeName,
    required this.memberIntercom,
    required this.memberStatus,
    required this.status,
    required this.socBuildingName,
    required this.unitFlatNumber,
    required this.buildingUnit,
    required this.approved,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'],
      memberId: json['member_id'],
      fkUnitId: json['fk_unit_id'],
      salute: json['salute'],
      memberName: json['member_name'],
      memberEmailId: json['member_email_id'],
      memberMobileNumber: json['member_mobile_number'],
      memberEffectiveDate: json['member_effective_date'],
      memberTypeName: json['member_type_name'],
      memberIntercom: json['member_intercom'],
      memberStatus: json['member_status'],
      status: json['status'],
      socBuildingName: json['soc_building_name'],
      unitFlatNumber: json['unit_flat_number'],
      buildingUnit: json['building_unit'],
      approved: json['approved'],
    );
  }

  static List<Member> fromJsonList(List<dynamic> jsonList) {
    return jsonList.map((json) => Member.fromJson(json)).toList();
  }
}
