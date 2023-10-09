import 'package:onegate_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

class VisitorLogEndpoint extends Endpoint {
  Future<VisitorLog> createVisitorLog(
      Session session, VisitorLog visitorLog) async {
    await VisitorLog.insert(session, visitorLog);
    return visitorLog;
  }

  Future<List<VisitorLog>> fetchCheckInVisitorLog(
      Session session, int companyId, DateTime dateTime) async {
    List<VisitorLog> visitorLogs = await VisitorLog.find(session,
        where: (v) => v.visitor_check_in.equals(dateTime));
    return visitorLogs;
  }
}
