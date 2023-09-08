import 'package:flutter_onegate/domain/entities/gate/camera_settings.dart';
import 'package:flutter_onegate/domain/entities/gate/gate_settings.dart';
import 'package:flutter_onegate/domain/entities/gate/language_setting.dart';
import 'package:flutter_onegate/domain/entities/gate/visit_settings.dart';
import 'package:flutter_onegate/domain/mappers/gate/camera_settings_mapper.dart';
import 'package:flutter_onegate/domain/mappers/gate/language_settings_mapper.dart';
import 'package:flutter_onegate/domain/mappers/gate/visit_settings_mapper.dart';

class GateSettingsMapper {
  static GateSettings fromJson(Map<String, dynamic> json) {
    return GateSettings(
      cameraSettings: CameraSettings.fromJson(json['cameraSettings']),
      visitSettings: VisitSettings.fromJson(json['visitSettings']),
      languageSettings: LanguageSettings.fromJson(json['languageSettings']),
      visitorApprovalTime: json['visitorApprovalTime'],
      offlineDataStorageDuration: json['offlineDataStorageDuration'],
    );
  }

  static Map<String, dynamic> toJson(GateSettings settings) {
    return {
      'cameraSettings': CameraSettingsMapper.toJson(settings.cameraSettings),
      'visitSettings': VisitSettingsMapper.toJson(settings.visitSettings),
      'languageSettings': LanguageSettingsMapper.toJson(settings.languageSettings),
      'visitorApprovalTime': settings.visitorApprovalTime,
      'offlineDataStorageDuration': settings.offlineDataStorageDuration,
    };
  }
}