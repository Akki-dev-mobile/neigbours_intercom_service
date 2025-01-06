import 'dart:io';

import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';
import 'package:flutter_onegate/domain/repositories/visitor_repo.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VisitorRepoImpl extends VisitorRepository {
  final RemoteDataSource _remoteDataSource;

  VisitorRepoImpl(this._remoteDataSource);

  @override
  Future<VisitorMapper?> searchVisitor(String mobileNumber) async {
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
  Future<List<dynamic>?>? getUnitList(int companyId) async {
    try {
      final response = await _remoteDataSource.getUnitsList(companyId);
      return response;
    } catch (error) {
      return null;
    }
  }

  @override
  Future<List<dynamic>?>? getBuildingList(int companyId) async {
    try {
      final response = await _remoteDataSource.getBuildingsList();
      return response;
    } catch (error) {
      return null;
    }
  }

  @override
  Future<List<dynamic>?>? getMembersList(int companyId) async {
    try {
      final response = await _remoteDataSource.getMembersList();
      return response;
    } catch (error) {
      return null;
    }
  }

  @override
  Future<VisitorMapper?> createVisitor(VisitorMapper visitor) async {
    try {
      final response = await _remoteDataSource.createVisitor(visitor);
      print("createVisitor visitor_repo_impl::: $response");
      return response;
    } catch (error) {
      return null;
    }
  }

  @override
  Future<String?> uploadImage(
      File file, String userMobile, int companyId) async {
    try {
      final response = await _remoteDataSource.uploadFile(
        file,
        userMobile,
        companyId,
      );

      print("ResponseImage::: $response");

      if (response != null) {
        // Save the image URL to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('uploaded_image_url', response);
        print("Image URL saved to SharedPreferences: $response");
      }

      return response;
    } catch (error) {
      print("Error uploading image: $error");
      return null;
    }
  }

  @override
  Future<bool> updateVisitor(VisitorMapper visitor) async {
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
  Future<String?> verifyOTP(String mobileNumber, String otp) async {
    try {
      final response = await _remoteDataSource.verifyOTP(mobileNumber, otp);
      return response;
    } catch (error) {
      return error.toString();
    }
  }
}
