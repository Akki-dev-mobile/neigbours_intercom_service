part of 'request_gate_access_bloc.dart';

@immutable
class RequestGateAccessState {}

abstract class RequestGateAccessActionState extends RequestGateAccessState {}

class RequestGateAccessInitial extends RequestGateAccessState {}

class RequestAccessLoadingState extends RequestGateAccessState {}

class RequestAccessButtonPressedState extends RequestGateAccessActionState {
  final String name;
  final String mobile;
  final String societyName;

  RequestAccessButtonPressedState({
    required this.name,
    required this.mobile,
    required this.societyName,
  });
}

class RequestAccessErrorState extends RequestGateAccessState {
  final String message;

  RequestAccessErrorState(this.message);
}
