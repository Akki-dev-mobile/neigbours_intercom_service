import 'package:flutter_onegate/domain/entities/gate/gate_list_response.dart';

abstract class GateRepository {
  Future<GateListResponse?> gateList(int companyId, int userId);
}