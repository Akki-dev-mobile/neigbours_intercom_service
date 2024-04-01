import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:onegate_client/onegate_client.dart';

abstract class VisitorRepository {
  Future<Visitor?> searchVisitor(String mobileNumber);
  Future<List<PurposeCategory>?>? fetchPurposeCategory();
  Future<String?> uploadImage(File file, String userMobile, int companyId);
  Future<Visitor?> createVisitor(Visitor visitor);
  Future<bool> updateVisitor(Visitor visitor); 
  Future<String?> sendOTP(String mobileNumber); 
  Future<String?>verifyOTP(String mobileNumber, String otp);
}
