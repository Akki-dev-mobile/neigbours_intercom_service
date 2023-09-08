class LanguageSettings {
  final String language;

  LanguageSettings({
    required this.language,
  });

  factory LanguageSettings.fromJson(Map<String, dynamic> json) {
    return LanguageSettings(
      language: json['language'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language': language,
    };
  }
}