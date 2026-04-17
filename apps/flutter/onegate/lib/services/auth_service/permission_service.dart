import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> checkAndRequestLocationPermission(
      BuildContext context) async {
    final status = await Permission.location.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.location.request();
      if (result.isGranted) {
        return true;
      }
    }

    if (status.isPermanentlyDenied || Platform.isIOS) {
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(context.tr('Location Permission Required')),
            content: Text(
              context.tr(
                'Please enable location permissions in your device settings to use this feature.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('Cancel')),
              ),
              TextButton(
                onPressed: () {
                  openAppSettings();
                  Navigator.pop(context);
                },
                child: Text(context.tr('Open Settings')),
              ),
            ],
          ),
        );
      }
    }

    return false;
  }
}
