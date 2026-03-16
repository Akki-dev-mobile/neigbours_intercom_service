import 'app.dart';

class Company {
  final int? companyId; // Made nullable to handle missing values
  final String? companyName;
  final List<App>? apps;
  final List<int>? accessTo;
  /// Roles from gate API (e.g. [master, gatekeeper]). Used for native login role selection.
  final List<String>? userRoles;

  Company({
    this.companyId,
    this.companyName,
    this.apps,
    this.accessTo,
    this.userRoles,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    // Use null-aware operators and provide default empty list if apps/access_to are null
    final appsJson = json['apps'] as List? ?? [];
    final apps = appsJson.map((appJson) => App.fromJson(appJson)).toList();

    final accessTo = (json['access_to'] as List? ?? []).cast<int>();

    final userRolesRaw = json['user_roles'] as List? ?? [];
    final userRoles = userRolesRaw.map((e) => e.toString()).toList();

    // Parse company_id robustly: API may return int or string (e.g. "42")
    int? companyId;
    final raw = json['company_id'];
    if (raw is int) {
      companyId = raw;
    } else if (raw is String && raw.isNotEmpty) {
      companyId = int.tryParse(raw);
    }

    return Company(
      companyId: companyId,
      companyName: json['company_name'] as String?,
      apps: apps,
      accessTo: accessTo,
      userRoles: userRoles.isEmpty ? null : userRoles,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_id': companyId,
      'company_name': companyName,
      'apps': apps?.map((app) => app.toJson()).toList(),
      'access_to': accessTo,
      'user_roles': userRoles,
    };
  }
}
