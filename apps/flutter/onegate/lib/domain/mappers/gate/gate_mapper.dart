import 'package:flutter_onegate/domain/entities/gate/gate.dart';
import 'package:flutter_onegate/domain/entities/gate/gate_configuration.dart';
import 'package:flutter_onegate/domain/entities/gate/gate_settings.dart';
import 'package:flutter_onegate/domain/mappers/gate/gate_configuration_mapper.dart';
import 'package:flutter_onegate/domain/mappers/gate/gate_settings_mapper.dart';

class GateMapper {
  static Gate fromJson(Map<String, dynamic> json) {
    return Gate(
      name: json['name'],
      gatekeeperId: json['gatekeeperId'],
      configuration: GateConfiguration.fromJson(json['configuration']),
      settings: GateSettings.fromJson(json['settings']),
      isSelected: false,
    );
  }

  static Map<String, dynamic> toJson(Gate gate) {
    return {
      'name': gate.name,
      'gatekeeperId': gate.gatekeeperId,
      'configuration': GateConfigurationMapper.toJson(gate.configuration),
      'settings': GateSettingsMapper.toJson(gate.settings),
    };
  }
}