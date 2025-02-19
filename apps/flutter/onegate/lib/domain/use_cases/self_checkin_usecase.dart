// import 'package:flutter_onegate/domain/repositories/visitor_repo.dart';
//
// class SelfCheckinUsecase {
//   final VisitorRepository _repository;
//
//   SelfCheckinUsecase(this._repository);
//
//   /// Sends an OTP for self-checkin.
//   /// Returns true if the OTP was sent successfully.
//   Future<bool> sendSelfCheckinOTP(String mobileNumber) async {
//     return await _repository.sendSelfCheckinOTP(mobileNumber);
//   }
//
//   /// Verifies the self-checkin OTP.
//   /// Returns the response data as a Map if the OTP is verified successfully,
//   /// or null if verification fails.
//   Future<Map<String, dynamic>?> verifySelfCheckinOTP(String mobileNumber, String otp) async {
//     return await _repository.verifySelfCheckinOTP(mobileNumber, otp);
//   }
// }
