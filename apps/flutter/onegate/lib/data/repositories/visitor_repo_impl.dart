import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/visitor.dart';
import 'package:flutter_onegate/domain/mappers/visitor_mapper.dart';
import 'package:flutter_onegate/domain/repositories/visitor_repo.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';

class VisitorRepoImpl extends VisitorRepository{
  final RemoteDataSource _remoteDataSource;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();

  VisitorRepoImpl(this._remoteDataSource);
  @override
  Future<Visitor?> searchVisitor(String mobileNumber) async {
    try {
      final response =
          await _remoteDataSource.searchVisitor(mobileNumber,_preferenceUtils.getAccessToken()!.accessToken,_preferenceUtils.getSelectedCompany()!.companyId);
      final visitorResponse = VisitorMapper.fromJson(response);
      return visitorResponse;
    } catch (error) {
      return null; // Handle error or authentication failure
    }
  }
  
}