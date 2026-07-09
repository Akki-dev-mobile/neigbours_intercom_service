import 'package:flutter/widgets.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

String intercomTr(
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
  return translated == key ? fallback : translated;
}
