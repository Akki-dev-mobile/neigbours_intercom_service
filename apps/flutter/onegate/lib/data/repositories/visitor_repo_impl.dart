import 'dart:io';

import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/repositories/visitor_repo.dart';
import 'package:image_picker/image_picker.dart';
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
  Future<List<PurposeCategory>?>? fetchPurposeCategory() async {
    try {
      final response = await _remoteDataSource.fetchPurpose();
      return response;
    } catch (error) {
      return null;
    }
  }

  @override
  Future<Visitor?> createVisitor(Visitor visitor) async {
    try {
      final response = await _remoteDataSource.createVisitor(visitor);
      return response;
    } catch (error) {
      return null;
    }
  }

  @override
  Future<String?> uploadImage(
      File file, String userMobile, int companyId) async {
    try {
      final response =
          await _remoteDataSource.uploadFile(file, userMobile, companyId);
      return response;
    } catch (error) {
      return null;
    }
  }

  @override
  Future<bool> updateVisitor(Visitor visitor) async {
    try {
      final response = await _remoteDataSource.updateVisitor(visitor);
      return response;
    } catch (error) {
      return false;
    }
  }

  @override
  Future<String?> sendOTP(String mobileNumber) async {
    try {
      final response = await _remoteDataSource.sendOTP(mobileNumber);
      return response;
    } catch (error) {
      return error.toString();
    }
  }
  
  @override
  Future<String?> verifyOTP(String mobileNumber, String otp) async{
    try {
      final response = await _remoteDataSource.verifyOTP(mobileNumber,otp);
      return response;
    } catch (error) {
      return error.toString();
    }
  }


}
