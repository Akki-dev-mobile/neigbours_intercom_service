import 'dart:io';

import 'package:dio/dio.dart';

/// Minimal API client used by the extracted module for image uploads.
///
/// Host apps may want to replace this with their own backend implementation.
class PostApiClient {
  final Dio _dio;

  PostApiClient(this._dio);

  Future<String?> uploadImage(File file) async {
    // The legacy app used a posts API. For a reusable package, the upload
    // endpoint is app-specific; returning null keeps the UI resilient.
    //
    // Host apps can fork this file and implement a real upload.
    return null;
  }
}

