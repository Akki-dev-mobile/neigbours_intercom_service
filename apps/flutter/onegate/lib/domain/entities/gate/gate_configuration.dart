import 'package:flutter_onegate/domain/entities/gate/gate%20_settings.dart';

class GateConfigurations {
  final bool visitorIn;
  final bool visitorOut;
  final bool vehicleIn;
  final bool vehicleOut;
  final GateSettings settings;

  GateConfigurations({
    required this.visitorIn,
    required this.visitorOut,
    required this.vehicleIn,
    required this.vehicleOut,
    required this.settings,
  });

  factory GateConfigurations.fromJson(Map<String, dynamic> json) {
    return GateConfigurations(
      visitorIn: json['visitorIn'] as bool,
      visitorOut: json['visitorOut'] as bool,
      vehicleIn: json['vehicleIn'] as bool,
      vehicleOut: json['vehicleOut'] as bool,
      settings: GateSettings.fromJson(json['settings']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'visitorIn': visitorIn,
      'visitorOut': visitorOut,
      'vehicleIn': vehicleIn,
      'vehicleOut': vehicleOut,
      'settings': settings.toJson(),
    };
  }
}