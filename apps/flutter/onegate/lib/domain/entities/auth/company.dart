import 'package:flutter_onegate/domain/entities/auth/app.dart';

class Company {
  final int companyId;
  final String companyName;
  final List<App> apps;
  final List<int> accessTo;

  Company({
    required this.companyId,
    required this.companyName,
    required this.apps,
    required this.accessTo,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    final appsJson = json['apps'] as List;
    final apps = appsJson.map((appJson) => App.fromJson(appJson)).toList();
    final accessTo = (json['access_to'] as List).cast<int>();

    return Company(
      companyId: json['company_id'],
      companyName: json['company_name'],
      apps: apps,
      accessTo: accessTo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_id': companyId,
      'company_name': companyName,
      'apps': apps,
      'access_to': accessTo,
    };
  }
}
