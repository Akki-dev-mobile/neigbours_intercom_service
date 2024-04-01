part of 'self_entry_bloc.dart';

@immutable
abstract class SelfEntryEvent {}

class SEOnMobileNumberEnteredEvent extends SelfEntryEvent {
  final String mobileNumber;

  SEOnMobileNumberEnteredEvent({required this.mobileNumber});
}

class SEVerifyOtpEvent extends SelfEntryEvent {
  final String otp;
  final String mobileNumber;

  SEVerifyOtpEvent(this.mobileNumber, {required this.otp});
} 
