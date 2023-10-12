import 'package:flutter_onegate/domain/repositories/visitor_repo.dart';
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

  Future<Visitor?> createVisitor(Visitor visitor) async {
    return await _repository.createVisitor(visitor);
  }
}
