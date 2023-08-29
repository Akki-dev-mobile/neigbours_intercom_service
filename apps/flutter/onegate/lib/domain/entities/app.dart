
class App {
  final int appId;
  final String appName;
  final String productCode;
  final List<String> roles;

  App({
    required this.appId,
    required this.appName,
    required this.productCode,
    required this.roles,
  });

  factory App.fromJson(Map<String, dynamic> json) {
    final rolesJson = json['roles'] as List;
    final roles = rolesJson.cast<String>();

    return App(
      appId: json['app_id'],
      appName: json['app_name'],
      productCode: json['product_code'],
      roles: roles,
    );
  }

  Map<String,dynamic> toJson() {
    return{
      'app_id': appId,
      'app_name': appName,
      'product_code': productCode,
      'roles': roles,
    };
  }
}