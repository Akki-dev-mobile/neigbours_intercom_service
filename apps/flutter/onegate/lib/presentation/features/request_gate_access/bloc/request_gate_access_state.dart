part of 'request_gate_access_bloc.dart';

@immutable
class RequestGateAccessState {}

abstract class RequestGateAccessActionState extends RequestGateAccessState {}

class RequestGateAccessInitial extends RequestGateAccessState {}

class RequestAccessButtonPressedState extends RequestGateAccessActionState {}
