import 'dart:math';

import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/repositories/visitor_log_repo.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLogMapper.dart';

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
      int companyId, String dateTime) async {
    try {
      final response =
          await _remoteDataSource.fetchCheckInLogs(companyId, dateTime);
      return response;
    } catch (error) {
      return null;
    }
  }

  @override
  Future<List<VisitorLog>?> fetchAllVisitorLog(
      int companyId, String dateTime) async {
    try {
      final response =
          await _remoteDataSource.fetchAllLogs(companyId,dateTime);
      return response;
    } catch (error) {
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
      int companyId, String dateTime) async {
    try {
      final response =
          await _remoteDataSource.fetchCheckOutLogs(companyId, dateTime);
      return response;
    } catch (error) {
      return null;
    }
  }
}
