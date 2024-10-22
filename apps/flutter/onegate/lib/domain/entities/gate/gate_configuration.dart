class GateConfiguration {
  final bool allowVisitorIn;
  final bool allowVisitorOut;
  final bool allowVehicleIn;
  final bool allowVehicleOut;

  GateConfiguration({
    required this.allowVisitorIn,
    required this.allowVisitorOut,
    required this.allowVehicleIn,
    required this.allowVehicleOut,
  });

  factory GateConfiguration.fromJson(Map<String, dynamic> json) {
    return GateConfiguration(
      allowVisitorIn: json['allowVisitorIn'],
      allowVisitorOut: json['allowVisitorOut'],
      allowVehicleIn: json['allowVehicleIn'],
      allowVehicleOut: json['allowVehicleOut'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allowVisitorIn': allowVisitorIn,
      'allowVisitorOut': allowVisitorOut,
      'allowVehicleIn': allowVehicleIn,
      'allowVehicleOut': allowVehicleOut,
    };
  }
}