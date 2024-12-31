
import 'package:flutter_onegate/domain/entities/staff/staff_entity.dart';

abstract class StaffRepository {
  Future<List<StaffEntity>> getStaffList(String companyId);
}