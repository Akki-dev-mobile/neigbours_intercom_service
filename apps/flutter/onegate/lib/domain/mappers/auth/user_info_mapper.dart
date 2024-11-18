import 'package:flutter_onegate/domain/entities/auth/company.dart';
import 'package:flutter_onegate/domain/entities/auth/user_info.dart';

class UserInfoMapper {
  static UserInfo fromJson(Map<String, dynamic> json) {
    final dynamic companiesJson = json['companies'];
    print("companiesJson: $companiesJson");
    print('Type of companiesJson: ${companiesJson.runtimeType}');

    var companies = {};

    // Check if companiesJson is a Map with numeric keys
    if (companiesJson != null && companiesJson is Map<String, dynamic>) {
      companiesJson.forEach((key, value) {
        print("Processing key: $key with value: $value");

        // Check if the value is a list
        if (value is List) {
          List<Company> companyList = value
              .map((companyJson) => Company.fromJson(companyJson))
              .toList();
          companies[key] = companyList;
        }
      });
    } else {
      print("companiesJson is not a Map or is null");
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
}
