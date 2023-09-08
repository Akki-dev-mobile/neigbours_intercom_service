import 'package:flutter_onegate/domain/entities/auth/user_info.dart';
import 'package:flutter_onegate/domain/mappers/auth/company_mapper.dart';

class UserInfoMapper {
  static UserInfo fromJson(Map<String, dynamic> json) {
    final companiesJson = json['companies'] as Map<String, dynamic>;
    final companies = companiesJson.map((key, value) {
      return MapEntry(key, (value as List).map((companyJson) => CompanyMapper.fromJson(companyJson)).toList());
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