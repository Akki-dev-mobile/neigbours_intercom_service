import 'package:flutter_onegate/domain/entities/auth/company.dart';

class UserInfo {
  final int? userId;
  final String? firstName;
  final String? lastName;
  final String? username;
  final String? mobile;
  final String? email;
  var companies;
  final String? uuid;

  UserInfo({
    this.userId,
    this.firstName,
    this.lastName,
    this.username,
    this.mobile,
    this.email,
    this.companies,
    this.uuid,
  });

  // Updated factory method to handle both List and Map for 'companies'
  factory UserInfo.fromJson(Map<String, dynamic> json) {
    final dynamic companiesJson = json['companies'];
    Map<String, List<Company>> companies = {};

    // Handle case where 'companies' is a Map with numeric string keys
    if (companiesJson is Map<String, dynamic>) {
      companiesJson.forEach((key, value) {
        if (value is List) {
          // Parse the list of companies
          companies[key] = value
              .map((companyJson) => Company.fromJson(companyJson))
              .toList();
        }
      });
    }

    return UserInfo(
      userId: json['user_id'] as int?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      username: json['username'] as String?,
      mobile: json['mobile'] as String?,
      email: json['email'] as String?,
      companies: companies,
      uuid: json['uuid'] as String?,
    );
  }

  // Convert the UserInfo object to JSON
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'username': username,
      'mobile': mobile,
      'email': email,
      'companies': companies?.map((key, value) => MapEntry(
            key,
            value.map((company) => company.toJson()).toList(),
          )),
      'uuid': uuid,
    };
  }
}
