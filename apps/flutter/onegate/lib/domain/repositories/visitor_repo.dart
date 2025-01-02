import 'dart:io';

import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';
import 'package:onegate_client/onegate_client.dart';

abstract class VisitorRepository {
  Future<VisitorMapper?> searchVisitor(String mobileNumber);
  Future<List<PurposeCategory>?>? fetchPurposeCategory();
  Future<List<dynamic>?>? getMembersList(int companyId);
  Future<List<dynamic>?>? getBuildingList(int companyId);
  Future<List<dynamic>?>? getUnitList(int companyId);
  Future<String?> uploadImage(File file, String userMobile, int companyId);
  Future<VisitorMapper?> createVisitor(VisitorMapper visitor);
  Future<bool> updateVisitor(VisitorMapper visitor);
  Future<String?> sendOTP(String mobileNumber);
  Future<String?> verifyOTP(String mobileNumber, String otp);
}
