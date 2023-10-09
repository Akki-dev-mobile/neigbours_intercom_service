import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/repositories/visitor_repo.dart';
import 'package:onegate_client/onegate_client.dart';

class VisitorRepoImpl extends VisitorRepository {
  final RemoteDataSource _remoteDataSource;

  VisitorRepoImpl(this._remoteDataSource);
  @override
  Future<Visitor?> searchVisitor(String mobileNumber) async {
    try {
      final response = await _remoteDataSource.searchVisitor(mobileNumber);
      return response;
    } catch (error) {
      return null; // Handle error or authentication failure
    }
  }
  
  @override
  Future<List<PurposeCategory>?>? fetchPurposeCategory() {
    try{
      final response = _remoteDataSource.fetchPurpose();
      return response;
    }catch(error){
      return null;
    } 
  }
}
