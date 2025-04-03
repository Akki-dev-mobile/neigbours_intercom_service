import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';

class LicensePlateRepository {
  final Dio _dio = Dio();

  Future<String> detectLicensePlate(File imageFile) async {
    try {
      FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(imageFile.path,
            filename: imageFile.path.split('/').last),
      });
      log(formData.files.first.value.filename.toString());
      Response response = await _dio.post(
        'http://192.168.1.12:6000/detect_license_plate',
        data: formData,
      );

      if (response.statusCode == 200 && response.data['success']) {
        log(response.data['license_plate_text']);

        return response.data['license_plate_text'];
      } else {
        throw response.data['error'] ?? 'Unknown error occurred';
      }
    } catch (e) {
      log(e.toString());
      throw e.toString();
    }
  }
}
