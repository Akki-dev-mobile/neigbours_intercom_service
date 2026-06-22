import '../config/intercom_module_config.dart';

/// Synchronous cache mirrored from [IntercomModule.config.contextPort].
///
/// Populated by the host app bootstrap (e.g. OneGate) so Riverpod providers
/// like [selectedFlatProvider] stay in sync with async context ports.
class IntercomRuntimeCache {
  static int? selectedSocietyId;
  static int? currentUserNumericId;
  static String? currentUserUuid;

  static Future<void> syncFromConfiguredModule() async {
    if (!IntercomModule.isConfigured) return;
    final port = IntercomModule.config.contextPort;
    selectedSocietyId = await port.getSelectedSocietyId();
    currentUserUuid = await port.getCurrentUserUuid();
    currentUserNumericId = await port.getCurrentUserNumericId();
  }
}
