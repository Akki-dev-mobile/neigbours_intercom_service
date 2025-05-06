import 'dart:io';

import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/repositories/visitor_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelfCheckInRepoImpl extends VisitorRepository {
  final RemoteDataSource _remoteDataSource;

  SelfCheckInRepoImpl(this._remoteDataSource);

  @override
  Future<Visitor?> searchVisitor(String mobileNumber) async {
    try {
      final response = await _remoteDataSource.searchVisitor(mobileNumber);
      return response;
    } catch (error) {
      return null;
    }
  }

  @override
  Future<List<PurposeCategory1>?>? fetchPurposeCategory() async {
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
      return response['data'] as List<dynamic>;
    } catch (error) {
      return null;
    }
  }

  @override
  Future<Visitor?> createVisitor(Visitor visitor) async {
    try {
      final response = await _remoteDataSource.createVisitor(visitor);
      print("createVisitor visitor_repo_impl::: ${response?.name}");
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
  Future<String?> verifyOTP(String mobileNumber, String otp) async {
    try {
      final response = await _remoteDataSource.verifyOTP(mobileNumber, otp);
      return response;
    } catch (error) {
      return error.toString();
    }
  }

  // ------------------------------
  // Self Checkin Implementations
  // ------------------------------

  /// Sends an OTP for self-checkin.
  /// Returns true if successful, false otherwise.
  @override
  Future<bool> sendSelfCheckinOTP(String mobileNumber) async {
    try {
      // Call the self-checkin OTP API endpoint.
      await _remoteDataSource.sendOtpForSelfCheckIn(mobileNumber);
      return true;
    } catch (error) {
      print("Error sending self-checkin OTP: $error");
      return false;
    }
  }

  /// Verifies the self-checkin OTP.
  /// Returns a map of the response data if successful, or null if failed.
  @override
  Future<Map<String, dynamic>?> verifySelfCheckinOTP(
      String mobileNumber, String otp) async {
    try {
      final response = await _remoteDataSource.verifySelfCheckin(
        mobileNumber: mobileNumber,
        otp: otp,
      );
      return response;
    } catch (error) {
      print("Error verifying self-checkin OTP: $error");
      return null;
    }
  }
}
