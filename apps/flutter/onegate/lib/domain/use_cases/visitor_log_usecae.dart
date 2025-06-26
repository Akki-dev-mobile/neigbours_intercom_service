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
    int companyId,
    String dateTime, {
    int currentPage = 1,
    int perPage = 10,
    String? searchQuery,
  }) async {
    return await _repository.fetchCheckInVisitorLog(
      companyId,
      dateTime,
      currentPage: currentPage,
      perPage: perPage,
      searchQuery: searchQuery,
    );
  }

  Future<bool> checkOut(VisitorLog visitorLog) async {
    return await _repository.checkOut(visitorLog);
  }

  Future<List<VisitorLog>?> fetchAllLogs(
    int companyId,
    String dateTime, {
    int currentPage = 1,
    int perPage = 10,
    String? searchQuery,
  }) async {
    return await _repository.fetchAllVisitorLog(
      companyId,
      dateTime,
      currentPage: currentPage,
      perPage: perPage,
      searchQuery: searchQuery,
    );
  }

  Future<List<VisitorLog>?> fetchCheckOutLogs(
    int companyId,
    String dateTime, {
    int currentPage = 1,
    int perPage = 10,
    String? searchQuery,
  }) async {
    return await _repository.fetchCheckOutVisitorLog(
      currentPage: currentPage,
      perPage: perPage,
      searchQuery: searchQuery,
    );
  }

  /// Get visitor counts using V2 API
  /// Returns counts for total, checked-in, and checked-out visitors
  Future<Map<String, int>> getVisitorCounts(
      int companyId, String dateTime) async {
    // For now, we'll use the remote data source directly
    // In a proper architecture, this should go through the repository
    final RemoteDataSource remoteDataSource = RemoteDataSource();
    return await remoteDataSource.fetchVisitorCounts();
  }
}
