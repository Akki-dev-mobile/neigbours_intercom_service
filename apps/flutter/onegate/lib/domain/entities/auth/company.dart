import 'package:flutter_onegate/domain/entities/auth/app.dart';

class Company {
  final int? companyId; // Made nullable to handle missing values
  final String? companyName;
  final List<App>? apps;
  final List<int>? accessTo;

  Company({
    this.companyId,
    this.companyName,
    this.apps,
    this.accessTo,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    // Use null-aware operators and provide default empty list if apps/access_to are null
    final appsJson = json['apps'] as List? ?? [];
    final apps = appsJson.map((appJson) => App.fromJson(appJson)).toList();

    final accessTo = (json['access_to'] as List? ?? []).cast<int>();

    return Company(
      companyId: json['company_id'] as int?,
      companyName: json['company_name'] as String?,
      apps: apps,
      accessTo: accessTo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_id': companyId,
      'company_name': companyName,
      'apps': apps?.map((app) => app.toJson()).toList(),
      'access_to': accessTo,
    };
  }
}
