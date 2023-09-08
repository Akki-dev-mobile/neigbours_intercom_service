import 'package:flutter_onegate/domain/entities/gate/visit_settings.dart';

class VisitSettingsMapper {
  static VisitSettings fromJson(Map<String, dynamic> json) {
    return VisitSettings(
      visitorNameRequired: json['visitorNameRequired'],
      visitorAddressRequired: json['visitorAddressRequired'],
      visitorPurposeRequired: json['visitorPurposeRequired'],
      memberApprovalRequired: json['memberApprovalRequired'],
    );
  }

  static Map<String, dynamic> toJson(VisitSettings settings) {
    return {
      'visitorNameRequired': settings.visitorNameRequired,
      'visitorAddressRequired': settings.visitorAddressRequired,
      'visitorPurposeRequired': settings.visitorPurposeRequired,
      'memberApprovalRequired': settings.memberApprovalRequired,
    };
  }
}