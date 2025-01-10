part of 'self_entry_bloc.dart';

@immutable
class SelfEntryState {}

abstract class SelfEntryActionState extends SelfEntryState {}

class SelfEntryInitial extends SelfEntryState {}

class SelfEntryLoadingState extends SelfEntryState {}

class SelfEntryErrorState extends SelfEntryActionState {
  final String message;

  SelfEntryErrorState({required this.message});
}

class SESaveVisitorState extends SelfEntryActionState {
  final Visitor? visitor;

  SESaveVisitorState({this.visitor});
}

class SENavigateToOTPState extends SelfEntryActionState {
  final String? mobileNumber;
  final String timer;

  SENavigateToOTPState(this.timer, {this.mobileNumber});
}

class SEOtpVerfiedState extends SelfEntryActionState {
  final String? mobileNumber;

  SEOtpVerfiedState({required this.mobileNumber});

}


