import 'package:flutter_onegate/domain/entities/society/member.dart';

class MemberMapper {
  static Member fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'],
      name: json['name'],
      mobileNumber: json['mobile_number'],
      memberType: json['member_type'],
    );
  }

  static Map<String, dynamic> toJson(Member member) {
    return {
      'id': member.id,
      'name': member.name,
      'mobile_number': member.mobileNumber,
      'member_type': member.memberType,
    };
  }
}