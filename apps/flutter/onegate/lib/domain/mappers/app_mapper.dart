import 'package:flutter_onegate/domain/entities/app.dart';

class AppMapper {
  static App fromJson(Map<String, dynamic> json) {
    final rolesJson = json['roles'];
    final roles = _parseRoles(rolesJson);

    return App(
      appId: json['app_id'],
      appName: json['app_name'],
      productCode: json['product_code'],
      roles: roles,
    );
  }

  static List<String> _parseRoles(dynamic rolesJson) {
    if (rolesJson is List) {
      return List<String>.from(rolesJson.cast<String>());
    } else if (rolesJson is Map<String, dynamic>) {
      return rolesJson.values.cast<String>().toList();
    } else {
      return [];
    }
  }
}
