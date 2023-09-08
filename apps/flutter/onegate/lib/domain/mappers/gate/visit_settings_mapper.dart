import 'package:flutter_onegate/domain/entities/gate/visit_settings.dart';

class VisitSettingsMapper {
  static VisitSettings fromJson(Map<String, dynamic> json) {
    return VisitSettings(
      visitorNameMandatory: json['visitorNameMandatory'] as bool,
      visitorAddressMandatory: json['visitorAddressMandatory'] as bool,
      visitorPurposeMandatory: json['visitorPurposeMandatory'] as bool,
      memberApprovalMandatory: json['memberApprovalMandatory'] as bool,
    );
  }

  static Map<String, dynamic> toJson(VisitSettings visitSettings) {
    return {
      'visitorNameMandatory': visitSettings.visitorNameMandatory,
      'visitorAddressMandatory': visitSettings.visitorAddressMandatory,
      'visitorPurposeMandatory': visitSettings.visitorPurposeMandatory,
      'memberApprovalMandatory': visitSettings.memberApprovalMandatory,
    };
  }
}