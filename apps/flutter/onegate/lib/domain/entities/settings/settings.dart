class Settings {
  Map<String, dynamic> cardFacility;
  Map<String, dynamic> isSync;
  Map<String, dynamic> passFacility;
  Map<String, dynamic> status;
  Map<String, dynamic> visitorIn;
  Map<String, dynamic> visitorOut;
  Map<String, dynamic> vehicleIn;
  Map<String, dynamic> vehicleOut;
  String companyId;
  String createdAt;
  int gateId;
  String gateName;
  String gateType;

  Settings({
    required this.cardFacility,
    required this.isSync,
    required this.passFacility,
    required this.status,
    required this.visitorIn,
    required this.visitorOut,
    required this.vehicleIn,
    required this.vehicleOut,
    required this.companyId,
    required this.createdAt,
    required this.gateId,
    required this.gateName,
    required this.gateType,
  });

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      cardFacility: json['card_facility'],
      isSync: json['isSync'],
      passFacility: json['pass_facility'],
      status: json['status'],
      visitorIn: json['visitor_in'],
      visitorOut: json['visitor_out'],
      vehicleIn: json['vehicle_in'],
      vehicleOut: json['vehicle_out'],
      companyId: json['company_id'],
      createdAt: json['created_at'],
      gateId: json['gate_id'],
      gateName: json['gate_name'],
      gateType: json['gate_type'],
    );
  }
}
