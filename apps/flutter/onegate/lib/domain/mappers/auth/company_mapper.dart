import 'package:flutter_onegate/domain/entities/auth/company.dart';

class CompanyMapper {
  static Company fromJson(Map<String, dynamic> json) {
    print("Parsing company JSON: $json");

    // Safely handle the 'access_to' field with null checks and type conversions
    List<int> accessTo = [];

    print("${accessTo.runtimeType}");
    if (json.containsKey('access_to') && json['access_to'] is List) {
      final List<dynamic>? accessToList = json['access_to'] as List<dynamic>?;

      if (accessToList != null) {
        accessTo = accessToList
            .map((item) {
              // Try to convert each item to an integer if possible
              if (item is int) {
                return item;
              } else if (item is String) {
                return int.tryParse(item);
              } else {
                return null;
              }
            })
            .whereType<int>() // Filter out any null values
            .toList();
      }
    }

    print("Parsed accessTo list: $accessTo");

    return Company(
      companyId: json['company_id'] as int?,
      companyName: json['company_name'] as String?,
      accessTo: accessTo,
    );
  }
}
