class Member {
  int? id;
  dynamic memberId;
  int? fkUnitId;
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
    this.id,
    this.memberId,
    this.fkUnitId,
    this.salute,
    this.memberName,
    this.memberEmailId,
    this.memberMobileNumber,
    this.memberEffectiveDate,
    this.memberTypeName,
    this.memberIntercom,
    this.memberStatus,
    this.status,
    this.socBuildingName,
    this.unitFlatNumber,
    this.buildingUnit,
    this.approved,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    return Member(
      id: parseInt(json['id']),
      memberId: json['member_id'],
      fkUnitId: parseInt(json['fk_unit_id']),
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
    return jsonList
        .map((json) => Member.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
