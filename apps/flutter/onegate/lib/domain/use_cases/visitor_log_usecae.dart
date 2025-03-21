import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLogMapper.dart';
import 'package:flutter_onegate/domain/repositories/visitor_log_repo.dart';

class VisitorLogUsecase {
  final VisitorLogRepository _repository;

  VisitorLogUsecase(this._repository);

  Future<VisitorLog?> createVisitorLog(VisitorLog visitorLog) async {
    return await _repository.createVisitorLog(visitorLog);
  }

  Future<List<VisitorLog>?> fetchCheckInVisitorLog(
      int companyId, String dateTime,
      {int currentPage = 1, int perPage = 20}) async {
    return await _repository.fetchCheckInVisitorLog(
      companyId,
      dateTime,
      currentPage: currentPage,
      perPage: perPage,
    );
  }

  Future<bool> checkOut(VisitorLog visitorLog) async {
    return await _repository.checkOut(visitorLog);
  }

  Future<List<VisitorLog>?> fetchAllLogs(int companyId, String dateTime,
      {int currentPage = 1, int perPage = 20}) async {
    return await _repository.fetchAllVisitorLog(
      companyId,
      dateTime,
      currentPage: currentPage,
      perPage: perPage,
    );
  }

  Future<List<VisitorLog>?> fetchCheckOutLogs(int companyId, String dateTime,
      {int currentPage = 1, int perPage = 20}) async {
    return await _repository.fetchCheckOutVisitorLog(
      companyId,
      dateTime,
      currentPage: currentPage,
      perPage: perPage,
    );
  }
}
