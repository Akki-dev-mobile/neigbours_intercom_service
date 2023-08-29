

import 'package:flutter_onegate/domain/entities/company.dart';

class UserInfo {
  final int userId;
  final String firstName;
  final String lastName;
  final String username;
  final String mobile;
  final String email;
  final Map<String, List<Company>> companies;
  final String uuid;

  UserInfo({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.mobile,
    required this.email,
    required this.companies,
    required this.uuid,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    final companiesJson = json['companies'] as Map<String, dynamic>;
    final companies = companiesJson.map((key, value) {
      return MapEntry(key, (value as List).map((companyJson) => Company.fromJson(companyJson)).toList());
    });

    return UserInfo(
      userId: json['user_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      username: json['username'],
      mobile: json['mobile'],
      email: json['email'],
      companies: companies,
      uuid: json['uuid'],
    );
  }
}
