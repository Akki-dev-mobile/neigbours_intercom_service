import 'package:flutter_onegate/domain/entities/gate/gate.dart';
import 'package:flutter_onegate/domain/mappers/gate/gate_configuration_mapper.dart';

class GateMapper {
  static Gate fromJson(Map<String, dynamic> json) {
    return Gate(
      id: json['id'] as int,
      name: json['name'] as String,
      configurations: GateConfigurationsMapper.fromJson(json['configurations']),
      gatekeeperId: json['gatekeeperId'] as int,
    );
  }

  static Map<String, dynamic> toJson(Gate gate) {
    return {
      'id': gate.id,
      'name': gate.name,
      'configurations': GateConfigurationsMapper.toJson(gate.configurations),
      'gatekeeperId': gate.gatekeeperId,
    };
  }
}