class CameraSettings {
  final bool faceRecognition;

  CameraSettings({
    required this.faceRecognition,
  });

  factory CameraSettings.fromJson(Map<String, dynamic> json) {
    return CameraSettings(
      faceRecognition: json['faceRecognition'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'faceRecognition': faceRecognition,
    };
  }
}