
import 'package:flutter_onegate/domain/entities/gate/visit_settings.dart';

class GateSettings {
  final String cameraSetting;
  final VisitSettings visitSetting;
  final String languageSetting;
  final int visitorApprovalTime;
  final int offlineDataStorageDuration;

  GateSettings({
    required this.cameraSetting,
    required this.visitSetting,
    required this.languageSetting,
    required this.visitorApprovalTime,
    required this.offlineDataStorageDuration,
  });

  factory GateSettings.fromJson(Map<String, dynamic> json) {
    return GateSettings(
      cameraSetting: json['cameraSetting'] as String,
      visitSetting: VisitSettings.fromJson(json['visitSetting']),
      languageSetting: json['languageSetting'] as String,
      visitorApprovalTime: json['visitorApprovalTime'] as int,
      offlineDataStorageDuration: json['offlineDataStorageDuration'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cameraSetting': cameraSetting,
      'visitSetting': visitSetting.toJson(),
      'languageSetting': languageSetting,
      'visitorApprovalTime': visitorApprovalTime,
      'offlineDataStorageDuration': offlineDataStorageDuration,
    };
  }
}