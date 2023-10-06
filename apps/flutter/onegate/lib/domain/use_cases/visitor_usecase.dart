import 'package:flutter_onegate/domain/entities/visitor.dart';
import 'package:flutter_onegate/domain/repositories/visitor_repo.dart';

class VisitorUsecase {
  final VisitorRepository _repository;

  VisitorUsecase(this._repository);

  Future<Visitor?> searchVisitor(String mobileNUmber) async{
    return await _repository.searchVisitor(mobileNUmber);
  }
}