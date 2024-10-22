import 'package:flutter_onegate/domain/entities/gate/gate2.dart';

abstract class GateRepository {
  Future<List<Gate>?> gateList(int companyId);
}