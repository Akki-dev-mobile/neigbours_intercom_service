part of 'request_gate_access_bloc.dart';

@immutable
sealed class RequestGateAccessEvent {}

class RequestAccessButtonPressedEvent extends RequestGateAccessEvent {}
