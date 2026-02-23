import '../../src/config/intercom_module_config.dart';
import '../../src/runtime/intercom_runtime_cache.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  Future<int?> getSelectedSocietyId() async {
    final id = await IntercomModule.config.contextPort.getSelectedSocietyId();
    if (id != null) IntercomRuntimeCache.selectedSocietyId = id;
    return id;
  }

  /// Backwards compatibility: some code refers to "company" for society.
  Future<int?> getSelectedCompanyId() => getSelectedSocietyId();

  Future<int?> getUserId() async {
    final id = await IntercomModule.config.contextPort.getCurrentUserNumericId();
    if (id != null) IntercomRuntimeCache.currentUserNumericId = id;
    return id;
  }
}

