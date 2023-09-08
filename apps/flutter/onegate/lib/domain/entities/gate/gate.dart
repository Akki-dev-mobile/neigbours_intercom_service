import 'package:flutter_onegate/domain/entities/gate/gate_configuration.dart';

class Gate {
  final int id;
  final String name;
  final GateConfigurations configurations;
  final int gatekeeperId;

  Gate({
    required this.id,
    required this.name,
    required this.configurations,
    required this.gatekeeperId,
  });

  factory Gate.fromJson(Map<String, dynamic> json) {
    return Gate(
      id: json['id'] as int,
      name: json['name'] as String,
      configurations: GateConfigurations.fromJson(json['configurations']),
      gatekeeperId: json['gatekeeperId'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'configurations': configurations.toJson(),
      'gatekeeperId': gatekeeperId,
    };
  }
}