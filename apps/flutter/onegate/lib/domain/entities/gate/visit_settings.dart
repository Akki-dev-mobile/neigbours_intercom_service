
class VisitSettings {
  final bool visitorNameRequired;
  final bool visitorAddressRequired;
  final bool visitorPurposeRequired;
  final bool memberApprovalRequired;

  VisitSettings({
    required this.visitorNameRequired,
    required this.visitorAddressRequired,
    required this.visitorPurposeRequired,
    required this.memberApprovalRequired,
  });

  factory VisitSettings.fromJson(Map<String, dynamic> json) {
    return VisitSettings(
      visitorNameRequired: json['visitorNameRequired'],
      visitorAddressRequired: json['visitorAddressRequired'],
      visitorPurposeRequired: json['visitorPurposeRequired'],
      memberApprovalRequired: json['memberApprovalRequired'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'visitorNameRequired': visitorNameRequired,
      'visitorAddressRequired': visitorAddressRequired,
      'visitorPurposeRequired': visitorPurposeRequired,
      'memberApprovalRequired': memberApprovalRequired,
    };
  }
}