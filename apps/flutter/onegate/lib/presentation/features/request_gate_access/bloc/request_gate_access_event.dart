part of 'request_gate_access_bloc.dart';

@immutable
class RequestGateAccessEvent {}

class RequestAccessButtonPressedEvent extends RequestGateAccessEvent {
  final String name;
  final String mobile;
  final String societyName;

  RequestAccessButtonPressedEvent({
    required this.name,
    required this.mobile,
    required this.societyName,
  });
}
