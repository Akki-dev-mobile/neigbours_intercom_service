import 'dart:developer';

import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/repositories/visitor_log_repo.dart';

class VisitorLogRepositoryImpl extends VisitorLogRepository {
  final RemoteDataSource _remoteDataSource;

  VisitorLogRepositoryImpl(this._remoteDataSource);

  @override
  Future<VisitorLog?> createVisitorLog(VisitorLog visitorLog) async {
    try {
      final response = await _remoteDataSource.checkIn(visitorLog);
      return response;
    } catch (error) {
      return null;
    }
  }

  @override
  Future<List<VisitorLog>?> fetchCheckInVisitorLog(
      int companyId, String dateTime,
      {int currentPage = 1, int perPage = 20}) async {
    return await _remoteDataSource.fetchCheckInLogs(
        // current_page: currentPage,
        // per_page: perPage,
        );
  }

  Future<List<VisitorLog>?> fetchAllVisitorLog(int companyId, String dateTime,
      {int currentPage = 1, int perPage = 20}) async {
    return await _remoteDataSource.fetchAllLogs(
        // current_page: currentPage,
        // per_page: perPage,
        );
  }

  Future<List<VisitorLog>?> fetchCardNumbers(
      int companyId, String dateTime) async {
    try {
      final response = await _remoteDataSource.fetchCheckInLogs();

      final filteredLogs =
          response.where((log) => log.visitor_card_number != null).toList();

      return filteredLogs;
    } catch (error) {
      log("Error fetching card numbers: $error");
      return null;
    }
  }

  @override
  Future<bool> checkOut(VisitorLog visitorLog) async {
    try {
      final response = await _remoteDataSource.checkOut(visitorLog);
      return response;
    } catch (error) {
      return Future.value(false);
    }
  }

  @override
  Future<List<VisitorLog>?> fetchCheckOutVisitorLog(
      int companyId, String dateTime,
      {int currentPage = 1, int perPage = 20}) async {
    return await _remoteDataSource.fetchCheckOutLogs(
        // current_page: currentPage,
        // per_page: perPage,
        );
  }
}
