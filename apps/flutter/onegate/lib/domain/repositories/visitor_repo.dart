import 'dart:io';

import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';
import 'package:onegate_client/onegate_client.dart';

abstract class VisitorRepository {
  Future<Visitor?> searchVisitor(String mobileNumber);
  Future<List<PurposeCategory1>?>? fetchPurposeCategory();
  Future<List<dynamic>?>? getMembersList(int companyId);
  Future<List<dynamic>?>? getBuildingList(int companyId);
  Future<List<dynamic>?>? getUnitList(int companyId);
  Future<String?> uploadImage(File file, String userMobile, int companyId);
  Future<Visitor?> createVisitor(Visitor visitor);
  Future<bool> updateVisitor(Visitor visitor);
  Future<String?> sendOTP(String mobileNumber);
  Future<String?> verifyOTP(String mobileNumber, String otp);
}
