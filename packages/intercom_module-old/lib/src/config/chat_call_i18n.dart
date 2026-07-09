import 'package:flutter/widgets.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

String chatCallTr(
  BuildContext context,
  String key, {
  required String fallback,
  Map<String, String>? params,
}) {
  final translated = FlutterI18n.translate(
    context,
    key,
    translationParams: params,
  );
  if (translated != key) {
    return translated;
  }
  return _applyTranslationParams(fallback, params);
}

String _applyTranslationParams(
  String text,
  Map<String, String>? params,
) {
  if (params == null || params.isEmpty) {
    return text;
  }
  var result = text;
  for (final entry in params.entries) {
    result = result.replaceAll('{${entry.key}}', entry.value);
  }
  return result;
}
