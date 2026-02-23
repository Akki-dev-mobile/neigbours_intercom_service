import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../src/config/intercom_module_config.dart';

/// Minimal API client used by the extracted module for image uploads.
///
/// Host apps may want to replace this with their own backend implementation.
class PostApiClient {
  final Dio _dio;

  PostApiClient(this._dio);

  Future<String?> uploadImage(File file) async {
    final port = IntercomModule.config.uploadPort;
    if (port == null) return null;

    final bytes = await file.readAsBytes();
    final filename = file.path.split(Platform.pathSeparator).last;

    return port.uploadImage(
      filename: filename,
      bytes: bytes,
    );
  }
}
