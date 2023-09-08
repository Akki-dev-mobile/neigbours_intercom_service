import 'package:flutter_onegate/domain/entities/gate/gate%20_settings.dart';
import 'package:flutter_onegate/domain/mappers/gate/visit_settings_mapper.dart';

class GateSettingsMapper {
  static GateSettings fromJson(Map<String, dynamic> json) {
    return GateSettings(
      cameraSetting: json['cameraSetting'] as String,
      visitSetting: VisitSettingsMapper.fromJson(json['visitSetting']),
      languageSetting: json['languageSetting'] as String,
      visitorApprovalTime: json['visitorApprovalTime'] as int,
      offlineDataStorageDuration: json['offlineDataStorageDuration'] as int,
    );
  }

  static Map<String, dynamic> toJson(GateSettings settings) {
    return {
      'cameraSetting': settings.cameraSetting,
      'visitSetting': VisitSettingsMapper.toJson(settings.visitSetting),
      'languageSetting': settings.languageSetting,
      'visitorApprovalTime': settings.visitorApprovalTime,
      'offlineDataStorageDuration': settings.offlineDataStorageDuration,
    };
  }
}
