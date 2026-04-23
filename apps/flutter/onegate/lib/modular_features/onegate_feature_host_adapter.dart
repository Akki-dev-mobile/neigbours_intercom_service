import 'dart:developer';

import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';

Future<FeatureHost> createOneGateFeatureHost({
  void Function(String name, {Map<String, Object?> props})? tracker,
  void Function(String message, {Object? error, StackTrace? stackTrace})?
      logger,
}) async {
  final gateStorage = GateStorage();
  final tokenManager = EnhancedTokenRefreshManager();

  await tokenManager.initialize(gateStorage);

  final societyId = await gateStorage.getSocietyId();
  final userId = await gateStorage.getUserId();
  final roleRaw = await gateStorage.getRole();

  final role = _mapRole(roleRaw);

  if (societyId == null || societyId.isEmpty) {
    throw StateError('Missing societyId in GateStorage');
  }
  if (userId == null || userId.isEmpty) {
    throw StateError('Missing userId in GateStorage');
  }

  final ctx = SocietyContext(
    societyId: societyId,
    userId: userId,
    role: role,
  );

  final cfg = FeatureConfig(
    neighboursEnabled: false,
    guardIntercomEnabled: true,
    flags: {
      'onegate.gateBaseUrl': ApiUrls.gateBaseUrl,
      'onegate.societyBaseUrl': ApiUrls.societyBaseUrl,
      'onegate.chatApiBaseUrl': 'https://apigw.cubeone.in/chatapp/api/v1',
      'onegate.callApiBaseUrl': 'https://apigw.cubeone.in/meet-service/api/v1',
      'onegate.jitsiServerUrl': 'https://collab.cubeone.in',
    },
  );

  Future<AuthSession> authSessionProvider() async {
    final token = await tokenManager.getValidAccessToken() ??
        await gateStorage.getAccessToken();

    if (token == null || token.isEmpty) {
      throw StateError('Missing accessToken in GateStorage');
    }

    return AuthSession(
      accessToken: token,
      refresh: () async {
        await tokenManager.refreshTokenIfNeeded();
        final refreshed = await tokenManager.getValidAccessToken() ??
            await gateStorage.getAccessToken() ??
            '';
        return AuthSession(accessToken: refreshed);
      },
    );
  }

  return OneGateFeatureHostAdapter(
    kongBase: Uri.parse(ApiUrls.gateBaseUrl),
    authSessionProvider: authSessionProvider,
    contextProvider: () => ctx,
    configProvider: () => cfg,
    tracker: tracker,
    logger: logger ??
        (String message, {Object? error, StackTrace? stackTrace}) {
          log(message, error: error, stackTrace: stackTrace);
        },
  );
}

UserRole _mapRole(String? roleRaw) {
  final normalized = (roleRaw ?? '').toLowerCase();
  if (normalized.contains('guard') || normalized.contains('gate')) {
    return UserRole.guard;
  }
  if (normalized.contains('admin')) return UserRole.admin;
  return UserRole.resident;
}

/// App-layer adapter to wire plug-and-play feature packages into this app.
///
/// This lives in the host app (not inside feature packages) so it can call
/// existing auth/context/config systems without introducing coupling.
class OneGateFeatureHostAdapter implements FeatureHost {
  OneGateFeatureHostAdapter({
    required Uri kongBase,
    required Future<AuthSession> Function() authSessionProvider,
    required SocietyContext Function() contextProvider,
    required FeatureConfig Function() configProvider,
    void Function(String name, {Map<String, Object?> props})? tracker,
    void Function(String message, {Object? error, StackTrace? stackTrace})?
        logger,
  })  : _kongBase = kongBase,
        _authSessionProvider = authSessionProvider,
        _contextProvider = contextProvider,
        _configProvider = configProvider,
        _tracker = tracker,
        _logger = logger;

  final Uri _kongBase;
  final Future<AuthSession> Function() _authSessionProvider;
  final SocietyContext Function() _contextProvider;
  final FeatureConfig Function() _configProvider;
  final void Function(String name, {Map<String, Object?> props})? _tracker;
  final void Function(String message, {Object? error, StackTrace? stackTrace})?
      _logger;

  @override
  Uri kongBaseUri() => _kongBase;

  @override
  SocietyContext currentContext() => _contextProvider();

  @override
  FeatureConfig featureConfig() => _configProvider();

  @override
  Future<AuthSession> authSession() => _authSessionProvider();

  @override
  void track(String name, {Map<String, Object?> props = const {}}) {
    _tracker?.call(name, props: props);
  }

  @override
  void log(String message, {Object? error, StackTrace? stackTrace}) {
    _logger?.call(message, error: error, stackTrace: stackTrace);
  }
}
