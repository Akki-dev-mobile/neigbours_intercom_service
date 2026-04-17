import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/widgets/error_screen.dart';
import 'package:flutter_onegate/services/error_tracking/posthog_error_tracking_service.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';

/// A utility class to handle API errors consistently across the app
class ApiErrorHandler {
  /// Show error screen as a dialog
  static void showErrorScreen(BuildContext context, String message,
      {VoidCallback? onRetry}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: ErrorScreen(
          message: message,
          onRetry: onRetry ?? () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('Close')),
          ),
        ],
      ),
    );
  }

  /// Handle API response based on status code
  static Future<T?> handleResponse<T>({
    required Future<Response> apiCall,
    BuildContext? context,
    required T Function(dynamic data) onSuccess,
    Function(dynamic error)? onError,
  }) async {
    try {
      final response = await apiCall;

      if (response.statusCode == 200) {
        return onSuccess(response.data);
      } else {
        final errorMessage =
            'Error ${response.statusCode}: ${response.statusMessage ?? "Something went wrong"}';
        log('Non-200 status code: ${response.statusCode}');

        if (context != null) {
          showErrorScreen(context, errorMessage);
        }

        if (onError != null) {
          onError(response);
        }

        return null;
      }
    } on DioException catch (e) {
      log('Dio error: ${e.message}');

      String errorMessage = 'Network error';
      if (e.response != null) {
        errorMessage =
            'Error ${e.response?.statusCode}: ${e.response?.statusMessage ?? e.message}';
      }

      // Send network error to PostHog
      await PostHogErrorTrackingService.instance.captureNetworkError(
        error: e,
        url: e.requestOptions.uri.toString(),
        method: e.requestOptions.method,
        statusCode: e.response?.statusCode,
        requestData: e.requestOptions.data,
        responseData: e.response?.data,
      );

      if (context != null) {
        showErrorScreen(context, errorMessage);
      }

      if (onError != null) {
        onError(e);
      }

      return null;
    } catch (e) {
      log('Error handling response: $e');

      // Send general error to PostHog
      await PostHogErrorTrackingService.instance.captureError(
        error: e,
        context: 'api_response_handling',
        errorType: 'APIResponseError',
        isFatal: false,
      );

      if (context != null) {
        showErrorScreen(context, context.tr('Unexpected error occurred'));
      }

      if (onError != null) {
        onError(e);
      }

      return null;
    }
  }

  /// Show an error as a fullscreen error page (useful for initial data loading)
  static Widget buildErrorScreen(String message, {VoidCallback? onRetry}) {
    return Center(
      child: ErrorScreen(
        message: message,
        onRetry: onRetry,
      ),
    );
  }
}
