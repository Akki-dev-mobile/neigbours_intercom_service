
import 'package:flutter_onegate/domain/entities/gate/camera_settings.dart';

class CameraSettingsMapper {
  static CameraSettings fromJson(Map<String, dynamic> json) {
    return CameraSettings(
      faceRecognition: json['faceRecognition'],
    );
  }

  static Map<String, dynamic> toJson(CameraSettings settings) {
    return {
      'faceRecognition': settings.faceRecognition,
    };
  }
}