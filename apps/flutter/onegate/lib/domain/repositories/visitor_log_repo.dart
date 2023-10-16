import 'package:onegate_client/onegate_client.dart';

abstract class VisitorLogRepository{
  Future<VisitorLog?> createVisitorLog(VisitorLog visitorLog);
  Future<List<VisitorLog>?> fetchCheckInVisitorLog(int companyId, String dateTime);
  Future<bool> checkOut(VisitorLog visitorLog);
}