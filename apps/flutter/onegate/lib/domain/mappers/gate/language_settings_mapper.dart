import 'package:flutter_onegate/domain/entities/gate/language_setting.dart';

class LanguageSettingsMapper {
  static LanguageSettings fromJson(Map<String, dynamic> json) {
    return LanguageSettings(
      language: json['language'],
    );
  }

  static Map<String, dynamic> toJson(LanguageSettings settings) {
    return {
      'language': settings.language,
    };
  }
}