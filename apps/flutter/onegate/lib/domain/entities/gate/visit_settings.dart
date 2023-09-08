
class VisitSettings {
  final bool visitorNameMandatory;
  final bool visitorAddressMandatory;
  final bool visitorPurposeMandatory;
  final bool memberApprovalMandatory;

  VisitSettings({
    required this.visitorNameMandatory,
    required this.visitorAddressMandatory,
    required this.visitorPurposeMandatory,
    required this.memberApprovalMandatory,
  });

  factory VisitSettings.fromJson(Map<String, dynamic> json) {
    return VisitSettings(
      visitorNameMandatory: json['visitorNameMandatory'] as bool,
      visitorAddressMandatory: json['visitorAddressMandatory'] as bool,
      visitorPurposeMandatory: json['visitorPurposeMandatory'] as bool,
      memberApprovalMandatory: json['memberApprovalMandatory'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'visitorNameMandatory': visitorNameMandatory,
      'visitorAddressMandatory': visitorAddressMandatory,
      'visitorPurposeMandatory': visitorPurposeMandatory,
      'memberApprovalMandatory': memberApprovalMandatory,
    };
  }
}