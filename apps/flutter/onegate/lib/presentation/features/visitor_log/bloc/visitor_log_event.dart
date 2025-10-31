part of 'visitor_log_bloc.dart';

@immutable
abstract class VisitorLogEvent {}

class FetchCheckInLogEvent extends VisitorLogEvent {
  final DateTime date;
  final int currentPage;
  final int perPage;
  final String? searchQuery;

  FetchCheckInLogEvent(this.date,
      {this.currentPage = 1, this.perPage = 10, this.searchQuery});
}

class FetchCheckOutLogEvent extends VisitorLogEvent {
  final DateTime date;
  final int currentPage;
  final int perPage;
  final String? searchQuery;

  FetchCheckOutLogEvent(this.date,
      {this.currentPage = 1, this.perPage = 10, this.searchQuery});
}

class FetchVisitorLogEvent extends VisitorLogEvent {
  final DateTime date;
  final int currentPage;
  final int perPage;
  final String? searchQuery;

  FetchVisitorLogEvent(this.date,
      {this.currentPage = 1, this.perPage = 10, this.searchQuery});
}

class LoadMoreVisitorLogsEvent extends VisitorLogEvent {
  final int currentPage;
  final int perPage;
  final String filterType; // "all", "check_in", "check_out"
  final String? searchQuery;

  LoadMoreVisitorLogsEvent(this.currentPage, this.perPage,
      {this.filterType = "all", this.searchQuery});
}

class CheckOutEvent extends VisitorLogEvent {
  final VisitorLog visitorLog;
  final String screenType;

  CheckOutEvent(this.visitorLog, this.screenType);
}
