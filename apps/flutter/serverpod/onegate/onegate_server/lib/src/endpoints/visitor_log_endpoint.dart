import 'package:onegate_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

class VisitorLogEndpoint extends Endpoint {
  Future<VisitorLog> createVisitorLog(
      Session session, VisitorLog visitorLog) async {
    await VisitorLog.insert(session, visitorLog);
    return visitorLog;
  }

  Future<BuildingAssignment> createBuildingAssignment(
      Session session, BuildingAssignment buildingAssignment) async {
    await BuildingAssignment.insert(session, buildingAssignment);
    return buildingAssignment;
  }

  Future<List<VisitorLog>> fetchAllLogs(
      Session session, String dateTime) async {
    List<VisitorLog> visitorLog = await VisitorLog.find(session);
    for (VisitorLog log in visitorLog) {
      log.visitor_building_assignment = await BuildingAssignment.find(
        session,
        where: (p0) {
          return p0.company_id.equals(log.company_id);
        },
      );

      log.visitor = await Visitor.findSingleRow(session, where: (p0) {
        return p0.id.equals(log.visitor_id);
      });
    }
    return visitorLog;
  }
}
