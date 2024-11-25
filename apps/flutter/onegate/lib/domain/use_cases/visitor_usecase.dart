import 'package:flutter_onegate/domain/repositories/visitor_repo.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onegate_client/onegate_client.dart';

class VisitorUsecase {
  final VisitorRepository _repository;

  VisitorUsecase(this._repository);

  Future<Visitor?> searchVisitor(String mobileNUmber) async {
    return await _repository.searchVisitor(mobileNUmber);
  }

  Future<List<PurposeCategory>?>? fetchPurposeCategory() async {
    return await _repository.fetchPurposeCategory();
  }

  Future<List<dynamic>?>? getMembersList(int companyId) async {
    return await _repository.getMembersList(companyId);
  }

  Future<List<dynamic>?>? getUnitList(int companyId) async {
    return await _repository.getUnitList(companyId);
  }

  Future<List<dynamic>?>? getBuildingList(int companyId) async {
    return await _repository.getBuildingList(companyId);
  }

  Future<Visitor?> createVisitor(Visitor visitor) async {
    return await _repository.createVisitor(visitor);
  }

  Future<String?> uploadImage(
      XFile file, String userMobile, int companyId) async {
    return await _repository.uploadImage(file, userMobile, companyId);
  }

  Future<bool> updateVisitor(Visitor visitor) async {
    return await _repository.updateVisitor(visitor);
  }

  Future<String?> sendOTP(String mobileNumber) async {
    return await _repository.sendOTP(mobileNumber);
  }

  Future<String?> verifyOTP(String mobileNumber, String otp) async {
    return await _repository.verifyOTP(mobileNumber, otp);
  }
}
