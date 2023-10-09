

import 'package:onegate_client/onegate_client.dart';

abstract class VisitorRepository {
  Future<Visitor?> searchVisitor(String mobileNumber);
  Future<List<PurposeCategory>?>? fetchPurposeCategory();
}
