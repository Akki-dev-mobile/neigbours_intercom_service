import 'package:flutter_onegate/domain/entities/visitor.dart';

abstract class VisitorRepository {
  Future<Visitor?> searchVisitor(String mobileNumber);
}