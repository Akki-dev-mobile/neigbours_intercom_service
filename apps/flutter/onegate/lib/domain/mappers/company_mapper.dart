import 'package:flutter_onegate/domain/entities/company.dart';
import 'package:flutter_onegate/domain/mappers/app_mapper.dart';

class CompanyMapper {
  static Company fromJson(Map<String, dynamic> json) {
    final appsJson = json['apps'] as List;
    final apps = appsJson.map((appJson) => AppMapper.fromJson(appJson)).toList();
    final accessTo = (json['access_to'] as List).cast<int>();

    return Company(
      companyId: json['company_id'],
      companyName: json['company_name'],
      apps: apps,
      accessTo: accessTo,
    );
  }
}