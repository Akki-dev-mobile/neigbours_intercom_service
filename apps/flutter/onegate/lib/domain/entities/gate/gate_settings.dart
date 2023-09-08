import 'package:flutter_onegate/domain/entities/gate/camera_settings.dart';
import 'package:flutter_onegate/domain/entities/gate/language_setting.dart';
import 'package:flutter_onegate/domain/entities/gate/visit_settings.dart';

class GateSettings {
  final CameraSettings cameraSettings;
  final VisitSettings visitSettings;
  final LanguageSettings languageSettings;
  final String visitorApprovalTime;
  final String offlineDataStorageDuration;

  GateSettings({
    required this.cameraSettings,
    required this.visitSettings,
    required this.languageSettings,
    required this.visitorApprovalTime,
    required this.offlineDataStorageDuration,
  });

  factory GateSettings.fromJson(Map<String, dynamic> json) {
    return GateSettings(
      cameraSettings: CameraSettings.fromJson(json['cameraSettings']),
      visitSettings: VisitSettings.fromJson(json['visitSettings']),
      languageSettings: LanguageSettings.fromJson(json['languageSettings']),
      visitorApprovalTime: json['visitorApprovalTime'],
      offlineDataStorageDuration: json['offlineDataStorageDuration'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cameraSettings': cameraSettings.toJson(),
      'visitSettings': visitSettings.toJson(),
      'languageSettings': languageSettings.toJson(),
      'visitorApprovalTime': visitorApprovalTime,
      'offlineDataStorageDuration': offlineDataStorageDuration,
    };
  }
}