import 'package:flutter_onegate/domain/entities/society/member.dart';

class MemberUnit {
  int id;
  String unitName;
  List<Member> members;

  MemberUnit({
    required this.id,
    required this.unitName,
    required this.members,
  });

  factory MemberUnit.fromJson(Map<String, dynamic> json) {
    List<dynamic> memberList = json['members'];
    List<Member> memberData = memberList.map((memberJson) => Member.fromJson(memberJson)).toList();

    return MemberUnit(
      id: json['id'],
      unitName: json['unit_name'],
      members: memberData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'unit_name': unitName,
      'members': members.map((member) => member.toJson()).toList(),
    };
  }
}