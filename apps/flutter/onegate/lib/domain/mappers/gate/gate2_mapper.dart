import 'package:flutter_onegate/domain/entities/gate/gate2.dart';

class GateMapper {
  static Gate fromJson(Map<String, dynamic> json) {
    return Gate(
      id: json['id'],
      companyId: json['company_id'],
      gateName: json['gate_name'],
      gateType: json['gate_type'],
      userId: json['gate_user_id'],
      oldSsoUserId: json['old_sso_user_id'],
      status: json['status'],
      tag: json['tag'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      isSelected: false,
    );
  }

  static List<Gate> fromJsonList(List<dynamic> jsonList) {
    return jsonList.map((json) => fromJson(json)).toList();
  }
}
