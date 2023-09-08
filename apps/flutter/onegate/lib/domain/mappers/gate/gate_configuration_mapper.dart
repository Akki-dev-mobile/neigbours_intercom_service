
import 'package:flutter_onegate/domain/entities/gate/gate_configuration.dart';

class GateConfigurationMapper {
  static GateConfiguration fromJson(Map<String, dynamic> json) {
    return GateConfiguration(
      allowVisitorIn: json['allowVisitorIn'],
      allowVisitorOut: json['allowVisitorOut'],
      allowVehicleIn: json['allowVehicleIn'],
      allowVehicleOut: json['allowVehicleOut'],
    );
  }

  static Map<String, dynamic> toJson(GateConfiguration configuration) {
    return {
      'allowVisitorIn': configuration.allowVisitorIn,
      'allowVisitorOut': configuration.allowVisitorOut,
      'allowVehicleIn': configuration.allowVehicleIn,
      'allowVehicleOut': configuration.allowVehicleOut,
    };
  }
}