import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';

abstract class VisitorLogRepository {
  Future<VisitorLog?> createVisitorLog(VisitorLog visitorLog);

  Future<List<VisitorLog>?> fetchCheckInVisitorLog(
      int companyId, String dateTime,
      {int currentPage = 1, int perPage = 20});

  Future<List<VisitorLog>?> fetchAllVisitorLog(int companyId, String dateTime,
      {int currentPage = 1, int perPage = 20});

  Future<List<VisitorLog>?> fetchCheckOutVisitorLog(
      int companyId, String dateTime,
      {int currentPage = 1, int perPage = 20});

  Future<bool> checkOut(VisitorLog visitorLog);
}
