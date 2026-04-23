import 'package:dio/dio.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';

class IntercomApiClient {
  IntercomApiClient._(this._host, this._dio, this._baseUrl);

  final FeatureHost _host;
  final Dio _dio;
  final Uri _baseUrl;

  static IntercomApiClient fromHost(FeatureHost host) {
    final flags = host.featureConfig().flags;
    final raw = flags['onegate.chatApiBaseUrl'];
    final base = (raw is String && raw.trim().isNotEmpty)
        ? Uri.parse(raw.trim())
        : Uri.parse('https://apigw.cubeone.in/chatapp/api/v1');

    final dio = Dio(
      BaseOptions(
        baseUrl: base.toString(),
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    return IntercomApiClient._(host, dio, base);
  }

  Uri get baseUrl => _baseUrl;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final headers = await _headers();
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: Options(headers: headers),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    final headers = await _headers();
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(headers: headers),
    );
  }

  Future<Map<String, String>> _headers() async {
    final token = (await _host.authSession()).accessToken;
    final xUserId =
        _resolveXUserIdFromToken(token) ?? _host.currentContext().userId;
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'x-user-id': xUserId,
    };
  }
}

String? _resolveXUserIdFromToken(String token) {
  try {
    final decoded = JwtDecoder.decode(token);
    final candidates = [
      decoded['old_gate_user_id'],
      decoded['old_sso_user_id'],
      decoded['user_id'],
    ];
    for (final c in candidates) {
      final v = c?.toString().trim();
      if (v != null && v.isNotEmpty && int.tryParse(v) != null) return v;
    }
    return null;
  } catch (_) {
    return null;
  }
}
