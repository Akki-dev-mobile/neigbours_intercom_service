part of 'visitor_log_bloc.dart';

@immutable
abstract class VisitorLogEvent {}

class FetchCheckInLogEvent extends VisitorLogEvent {
  final DateTime date;
  final int currentPage;
  final int perPage;

  FetchCheckInLogEvent(this.date, {this.currentPage = 1, this.perPage = 20});
}

class FetchCheckOutLogEvent extends VisitorLogEvent {
  final DateTime date;
  final int currentPage;
  final int perPage;

  FetchCheckOutLogEvent(this.date, {this.currentPage = 1, this.perPage = 20});
}

class FetchVisitorLogEvent extends VisitorLogEvent {
  final DateTime date;
  final int currentPage;
  final int perPage;

  FetchVisitorLogEvent(this.date, {this.currentPage = 1, this.perPage = 20});
}

class LoadMoreVisitorLogsEvent extends VisitorLogEvent {
  final int currentPage;
  final int perPage;

  LoadMoreVisitorLogsEvent(this.currentPage, this.perPage);
}

class CheckOutEvent extends VisitorLogEvent {
  final VisitorLog visitorLog;
  final String screenType;

  CheckOutEvent(this.visitorLog, this.screenType);
}
