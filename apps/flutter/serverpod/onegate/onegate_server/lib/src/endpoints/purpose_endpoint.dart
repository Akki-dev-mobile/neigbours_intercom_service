import 'package:onegate_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

class PurposeCategoryEndpoint extends Endpoint{
  Future<List<PurposeCategory>> fetchPurposeCategory(Session session) async {
    List<PurposeCategory> purposeCategory = await PurposeCategory.find(session);
    return purposeCategory;
  }
}