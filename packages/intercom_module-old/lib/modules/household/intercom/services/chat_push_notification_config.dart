import '../../../../core/constants.dart';

/// Resolves cross-app routing keys for chat WebSocket and FCM.
class ChatPushNotificationConfig {
  ChatPushNotificationConfig._();

  static String resolveAppType({String? packageName}) {
    final pkg = (packageName ?? AppConstants.appPackageName ?? '')
        .toLowerCase();
    if (pkg.contains('onegate')) return 'onegate';
    return 'oneapp';
  }

  /// When OneGate sends a push, target OneApp users (and vice versa).
  static String crossAppTargetType([String? localAppType]) {
    final local = localAppType ?? resolveAppType();
    return local == 'onegate' ? 'oneapp' : 'onegate';
  }
}
