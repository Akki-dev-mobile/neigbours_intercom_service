import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static const String _continuousSessionActiveKey = 'continuous_session_active';
  static const String _tokenExpirationLogoutDisabledKey =
      'token_expiration_logout_disabled';
  static const String _autoLogoutDisabledKey = 'auto_logout_disabled';
  static const String _sessionTimeoutDisabledKey = 'session_timeout_disabled';
  static const String _idleTimeoutDisabledKey = 'idle_timeout_disabled';

  static const String _refreshExpiryEpochMsKey = 'refresh_expiry_epoch_ms';
  static const String _refreshTtlUsedSecondsKey = 'refresh_ttl_used_seconds';
  static const String _lastRefreshEpochMsKey = 'last_refresh_time_epoch_ms';

  Future<String?> read({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> write({required String key, required String value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> initializeContinuousSessionFlags() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_continuousSessionActiveKey, true);
    await prefs.setBool(_tokenExpirationLogoutDisabledKey, true);
    await prefs.setBool(_autoLogoutDisabledKey, true);
    await prefs.setBool(_sessionTimeoutDisabledKey, true);
    await prefs.setBool(_idleTimeoutDisabledKey, true);
  }

  Future<int?> getRefreshTtlUsedSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_refreshTtlUsedSecondsKey);
  }

  Future<void> saveLastRefreshTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastRefreshEpochMsKey, time.millisecondsSinceEpoch);
  }

  Future<DateTime?> getLastRefreshTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastRefreshEpochMsKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Stores refresh-expiry metadata in a resilient way.
  /// If backend omits refresh expiry metadata, we do not reuse stale expiry.
  /// We rebuild expiry using previous ttl if available, else safe fallback.
  Future<DateTime> saveRefreshExpiryMetadata({
    int? refreshExpiresInSeconds,
    int safeFallbackSeconds = 24 * 60 * 60,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    int ttlSeconds;
    if (refreshExpiresInSeconds != null && refreshExpiresInSeconds > 0) {
      ttlSeconds = refreshExpiresInSeconds;
    } else {
      final previousTtl = prefs.getInt(_refreshTtlUsedSecondsKey);
      ttlSeconds = (previousTtl != null && previousTtl > 0)
          ? previousTtl
          : safeFallbackSeconds;
    }

    final expiry = now.add(Duration(seconds: ttlSeconds));
    await prefs.setInt(_refreshTtlUsedSecondsKey, ttlSeconds);
    await prefs.setInt(_refreshExpiryEpochMsKey, expiry.millisecondsSinceEpoch);
    await prefs.setInt(_lastRefreshEpochMsKey, now.millisecondsSinceEpoch);
    return expiry;
  }

  Future<DateTime?> getRefreshExpiryMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    final epochMs = prefs.getInt(_refreshExpiryEpochMsKey);
    if (epochMs == null) return null;
    // Advisory metadata only. Do not use as authoritative logout trigger.
    return DateTime.fromMillisecondsSinceEpoch(epochMs);
  }

  Future<int?> getKeycloakTokenLifetime() async {
    // Host apps can store this if they need it.
    return null;
  }
}
