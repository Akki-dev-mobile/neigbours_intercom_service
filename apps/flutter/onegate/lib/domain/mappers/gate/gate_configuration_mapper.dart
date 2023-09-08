
import 'package:flutter_onegate/domain/entities/gate/gate_configuration.dart';
import 'package:flutter_onegate/domain/mappers/gate/gate_settings_mapper.dart';

class GateConfigurationsMapper {
  static GateConfigurations fromJson(Map<String, dynamic> json) {
    return GateConfigurations(
      visitorIn: json['visitorIn'] as bool,
      visitorOut: json['visitorOut'] as bool,
      vehicleIn: json['vehicleIn'] as bool,
      vehicleOut: json['vehicleOut'] as bool,
      settings: GateSettingsMapper.fromJson(json['settings']),
    );
  }

  static Map<String, dynamic> toJson(GateConfigurations configurations) {
    return {
      'visitorIn': configurations.visitorIn,
      'visitorOut': configurations.visitorOut,
      'vehicleIn': configurations.vehicleIn,
      'vehicleOut': configurations.vehicleOut,
      'settings': GateSettingsMapper.toJson(configurations.settings),
    };
  }
}