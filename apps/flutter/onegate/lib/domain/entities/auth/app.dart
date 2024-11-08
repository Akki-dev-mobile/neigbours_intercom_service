class App {
  final int? appId;
  final String? appName;
  final String? productCode;
  final List<String>? roles;

  App({
    this.appId,
    this.appName,
    this.productCode,
    this.roles,
  });

  factory App.fromJson(Map<String, dynamic> json) {
    // Use null-aware operators and provide default values where appropriate
    final rolesJson = json['roles'] as List? ??
        []; // Default to an empty list if roles is null
    final roles = rolesJson.cast<String>();

    return App(
      appId: json['app_id'] ?? 0, // Default to 0 if app_id is null
      appName: json['app_name'] ??
          'Unknown', // Default to 'Unknown' if app_name is null
      productCode: json['product_code'] ??
          'N/A', // Default to 'N/A' if product_code is null
      roles: roles,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'app_id': appId,
      'app_name': appName,
      'product_code': productCode,
      'roles': roles,
    };
  }
}
