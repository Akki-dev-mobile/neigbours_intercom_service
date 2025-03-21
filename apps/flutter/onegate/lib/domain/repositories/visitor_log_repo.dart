import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';

abstract class VisitorLogRepository {
  Future<VisitorLog?> createVisitorLog(VisitorLog visitorLog);

  Future<List<VisitorLog>?> fetchAllVisitorLog(int companyId, String dateTime);

  Future<List<VisitorLog>?> fetchCheckInVisitorLog(
      int companyId, String dateTime);

  Future<List<VisitorLog>?> fetchCheckOutVisitorLog();

  Future<bool> checkOut(VisitorLog visitorLog);
}
