import 'package:flutter_onegate/domain/repositories/visitor_log_repo.dart';
import 'package:onegate_client/onegate_client.dart';

class VisitorLogUsecase{
  final VisitorLogRepository _repository;
  VisitorLogUsecase(this._repository);

  Future<VisitorLog?> createVisitorLog(VisitorLog visitorLog) async{
    return await _repository.createVisitorLog(visitorLog);
  }

  Future<List<VisitorLog>?> fetchCheckInVisitorLog(int companyId, String dateTime) async{
    return await _repository.fetchCheckInVisitorLog(companyId, dateTime);
  }
}