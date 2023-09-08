import 'package:flutter_onegate/domain/entities/gate/gate_configuration.dart';
import 'package:flutter_onegate/domain/entities/gate/gate_settings.dart';

class Gate {
  final String name;
  final int gatekeeperId;
  final GateConfiguration configuration;
  final GateSettings settings;
  bool isSelected;

  Gate({
    required this.name,
    required this.gatekeeperId,
    required this.configuration,
    required this.settings,
    this.isSelected = false,
  });

  factory Gate.fromJson(Map<String, dynamic> json) {
    return Gate(
      name: json['name'],
      gatekeeperId: json['gatekeeperId'],
      configuration: GateConfiguration.fromJson(json['configuration']),
      settings: GateSettings.fromJson(json['settings']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'gatekeeperId': gatekeeperId,
      'configuration': configuration.toJson(),
      'settings': settings.toJson(),
    };
  }
}