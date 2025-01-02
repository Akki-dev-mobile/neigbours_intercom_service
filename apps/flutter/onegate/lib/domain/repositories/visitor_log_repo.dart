import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLogMapper.dart';

abstract class VisitorLogRepository {
  Future<VisitorLogMapper?> createVisitorLog(VisitorLogMapper visitorLog);
  Future<List<VisitorLog>?> fetchAllVisitorLog(int companyId, String dateTime);
  Future<List<VisitorLog>?> fetchCheckInVisitorLog(
      int companyId, String dateTime);
  Future<List<VisitorLog>?> fetchCheckOutVisitorLog(
      int companyId, String dateTime);
  Future<bool> checkOut(VisitorLog visitorLog);
}
