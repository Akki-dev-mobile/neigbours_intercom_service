import 'dart:convert';

class SettingsList {
  int id;
  String settingsName;
  Map<String, dynamic> options;
  String type;
  int gateId;
  int status;
  String createdAt;
  String updatedAt;

  SettingsList({
    required this.id,
    required this.settingsName,
    required this.options,
    required this.type,
    required this.gateId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SettingsList.fromJson(Map<String, dynamic> json) {
    return SettingsList(
      id: json['id'],
      settingsName: json['settings_name'],
      options: Map<String, dynamic>.from(jsonDecode(json['options'])),
      type: json['type'],
      gateId: json['gate_id'],
      status: json['status'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  @override
  String toString() {
    return 'Settings{id: $id, settingsName: $settingsName, options: $options, type: $type, gateId: $gateId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}
