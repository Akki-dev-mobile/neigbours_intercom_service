part of 'visitor_log_bloc.dart';

@immutable
abstract class VisitorLogEvent {}

class FetchCheckInLogEvent extends VisitorLogEvent {
  final DateTime dateTime;

  FetchCheckInLogEvent(this.dateTime);
}

class FetchCheckOutLogEvent extends VisitorLogEvent {
  final DateTime dateTime;

  FetchCheckOutLogEvent(this.dateTime);
}

class FetchVisitorLogEvent extends VisitorLogEvent {
  final DateTime dateTime;

  FetchVisitorLogEvent(this.dateTime);
}

class CheckOutEvent extends VisitorLogEvent {
  final VisitorLog visitorLog;

  CheckOutEvent(this.visitorLog);
}
