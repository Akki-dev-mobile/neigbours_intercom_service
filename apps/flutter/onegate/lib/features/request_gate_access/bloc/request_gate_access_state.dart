part of 'request_gate_access_bloc.dart';

@immutable
sealed class RequestGateAccessState {}

abstract class RequestGateAccessActionState extends RequestGateAccessState {}

final class RequestGateAccessInitial extends RequestGateAccessState {}

class RequestAccessButtonPressedState extends RequestGateAccessActionState {}
