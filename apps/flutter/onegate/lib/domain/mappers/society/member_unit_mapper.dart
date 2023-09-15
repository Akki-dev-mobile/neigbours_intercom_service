import 'package:flutter_onegate/domain/entities/society/member.dart';
import 'package:flutter_onegate/domain/entities/society/member_unit.dart';
import 'package:flutter_onegate/domain/mappers/society/member_mapper.dart';

class MemberUnitMapper {
  static MemberUnit fromJson(Map<String, dynamic> json) {
    List<dynamic> memberList = json['members'];
    List<Member> memberData = memberList.map((memberJson) => MemberMapper.fromJson(memberJson)).toList();

    return MemberUnit(
      id: json['id'],
      unitName: json['unit_name'],
      members: memberData,
    );
  }

  static Map<String, dynamic> toJson(MemberUnit unit) {
    return {
      'id': unit.id,
      'unit_name': unit.unitName,
      'members': unit.members.map((member) => MemberMapper.toJson(member)).toList(),
    };
  }
}