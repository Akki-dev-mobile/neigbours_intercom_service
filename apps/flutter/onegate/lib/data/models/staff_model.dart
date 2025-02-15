import 'package:flutter_onegate/domain/entities/staff/staff_entity.dart';

class StaffModel extends StaffEntity {
  StaffModel({
    required int id,
    required String name,
    required String category,
    required String staffBadgeNumber,
    required String staffContactNumber,
    required String staffDob,
    required String staffQualification,
    required String staffSkill,
    required String languageSpoken,
    required String status,
  }) : super(
          id: id,
          name: name,
          category: category,
          staffBadgeNumber: staffBadgeNumber,
          staffContactNumber: staffContactNumber,
          staffDob: staffDob,
          staffQualification: staffQualification,
          staffSkill: staffSkill,
          languageSpoken: languageSpoken,
          status: status,
        );

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: json['id'],
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      staffBadgeNumber: json['staff_badge_number'] ?? '',
      staffContactNumber: json['staff_contact_number'] ?? '',
      staffDob: json['staff_dob'] ?? '',
      staffQualification: json['staff_qualification'] ?? '',
      staffSkill: json['staff_skill'] ?? '',
      languageSpoken: json['language_spoken'] ?? '',
      status: json['status'] ?? '',
    );
  }
}
