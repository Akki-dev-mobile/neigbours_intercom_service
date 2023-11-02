import 'package:cross_file/src/types/interface.dart';
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
  Future<List<PurposeCategory>?>? fetchPurposeCategory() async{
    try{
      final response = await _remoteDataSource.fetchPurpose();
      return response;
    }catch(error){
      return null;
    } 
  }
  
  @override
  Future<Visitor?> createVisitor(Visitor visitor) async {
   try{
    final response = await _remoteDataSource.createVisitor(visitor);
    return response;
   }catch(error){
     return null;
   }
  }
  
  @override
  Future<String?> uploadImage(XFile file, String userMobile, int companyId) async{
    try{
      final response =await _remoteDataSource.uploadFile(file, userMobile, companyId);
      return response;
    }catch(error){
      return null;
    }
  }

 
}
