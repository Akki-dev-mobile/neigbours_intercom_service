import 'package:onegate_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

class VisitorEndpoint extends Endpoint{
  Future<Visitor?> fetchVisitor(Session session, String mobileNo) async {
    Visitor? visitor = await Visitor.findSingleRow(session, where: (v) => v.mobile.equals(mobileNo));
    return visitor;
  }

  Future<Visitor> createVisitor(Session session, Visitor visitor) async {
    await Visitor.insert(session, visitor);
    return visitor;
  }
}