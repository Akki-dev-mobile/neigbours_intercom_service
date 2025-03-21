part of 'visitor_log_bloc.dart';

@immutable
class VisitorLogState {}

class VisitorLogInitial extends VisitorLogState {}

class VisitorLogActionState extends VisitorLogState {}

class VisitorLogLoadingState extends VisitorLogState {}

class VisitorLogSuccessState extends VisitorLogState {
  final List<VisitorLog>? visitorLogs;

  VisitorLogSuccessState(this.visitorLogs);
}

class VisitorCheckInLogSuccessState extends VisitorLogActionState {}

class VisitorCheckOutLogSuccessState extends VisitorLogActionState {}

class VisitorLogErrorState extends VisitorLogActionState {
  final String? message;

  VisitorLogErrorState(this.message);
}

class VisitorLogCheckOutSuccessState extends VisitorLogActionState {
  final bool? isCheckOut;

  VisitorLogCheckOutSuccessState(this.isCheckOut);
}
