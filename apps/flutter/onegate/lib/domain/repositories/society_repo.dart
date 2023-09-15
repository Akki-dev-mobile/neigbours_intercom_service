import 'package:flutter_onegate/domain/entities/society/building.dart';

abstract class SocietyRepository {
  Future<Building?> getBuildings(int companyId);
}
