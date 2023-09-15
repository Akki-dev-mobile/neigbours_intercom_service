class Member {
  int id;
  String name;
  String mobileNumber;
  String memberType;

  Member({
    required this.id,
    required this.name,
    required this.mobileNumber,
    required this.memberType,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'],
      name: json['name'],
      mobileNumber: json['mobile_number'],
      memberType: json['member_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile_number': mobileNumber,
      'member_type': memberType,
    };
  }
}