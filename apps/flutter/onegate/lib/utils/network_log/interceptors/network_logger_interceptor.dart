import 'dart:convert';
import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/network_log.dart';
import '../services/network_log_service.dart';
import '../services/network_log_sync_service.dart';

class NetworkLoggerInterceptor extends Interceptor {
  final NetworkLogService _logService;
  final NetworkLogSyncService _syncService;
  final bool _enabled;

  NetworkLoggerInterceptor({
    required NetworkLogService logService,
    bool enabled = true,
  })  : _logService = logService,
        _syncService = NetworkLogSyncService(),
        _enabled = enabled;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_enabled || !kDebugMode) {
      return handler.next(options);
    }

    final requestBody = options.data != null
        ? options.data is FormData
            ? 'FormData: ${options.data.fields}'
            : jsonEncode(options.data)
        : null;

    final headers = <String, dynamic>{};
    options.headers.forEach((key, value) {
      headers[key] = value.toString();
    });

    final log = NetworkLog.fromRequest(
      url: options.uri.toString(),
      method: options.method,
      headers: headers,
      requestBody: requestBody,
      timestamp: DateTime.now(),
      gateId: _syncService.gateId,
      environment: _syncService.environment,
    );

    // Store the log ID in the options extras to retrieve it later
    options.extra['logId'] = log.id;
    options.extra['requestStartTime'] = DateTime.now().millisecondsSinceEpoch;

    _logService.addLog(log);

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!_enabled || !kDebugMode) {
      return handler.next(response);
    }

    final requestStartTime =
        response.requestOptions.extra['requestStartTime'] as int?;
    final duration = requestStartTime != null
        ? DateTime.now().millisecondsSinceEpoch - requestStartTime
        : 0;

    final logId = response.requestOptions.extra['logId'] as String?;
    if (logId != null) {
      final existingLog = _logService.getLogById(logId);
      if (existingLog != null) {
        String responseBody;
        try {
          if (response.data is Map || response.data is List) {
            responseBody = jsonEncode(response.data);
          } else {
            responseBody = response.data.toString();
          }
        } catch (e) {
          responseBody = 'Could not encode response data: ${response.data}';
        }

        final updatedLog = existingLog.withResponse(
          statusCode: response.statusCode ?? 0,
          responseBody: responseBody,
          duration: duration,
        );

        _logService.updateLog(updatedLog);
      }
    }

    handler.next(response);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    if (!_enabled || !kDebugMode) {
      return handler.next(err);
    }

    final requestStartTime =
        err.requestOptions.extra['requestStartTime'] as int?;
    final duration = requestStartTime != null
        ? DateTime.now().millisecondsSinceEpoch - requestStartTime
        : 0;

    final logId = err.requestOptions.extra['logId'] as String?;
    if (logId != null) {
      final existingLog = _logService.getLogById(logId);
      if (existingLog != null) {
        String errorMessage = 'Unknown error';

        if (err.response != null) {
          try {
            if (err.response!.data is Map || err.response!.data is List) {
              errorMessage = jsonEncode(err.response!.data);
            } else {
              errorMessage = err.response!.data.toString();
            }
          } catch (e) {
            errorMessage =
                'Error: ${err.message}, Status: ${err.response?.statusCode}';
          }
        } else {
          errorMessage = 'Error: ${err.message}';
        }

        final updatedLog = existingLog.withError(
          error: errorMessage,
          duration: duration,
        );

        if (err.response != null) {
          final responseLog = updatedLog.withResponse(
            statusCode: err.response!.statusCode ?? 0,
            responseBody: errorMessage,
            duration: duration,
          );
          _logService.updateLog(responseLog);
        } else {
          _logService.updateLog(updatedLog);
        }
      }
    }

    handler.next(err);
  }
}
