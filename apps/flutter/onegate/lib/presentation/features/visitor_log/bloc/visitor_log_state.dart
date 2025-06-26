part of 'visitor_log_bloc.dart';

@immutable
class VisitorLogState {}

class VisitorLogInitial extends VisitorLogState {}

class VisitorLogActionState extends VisitorLogState {}

class VisitorLogLoadingState extends VisitorLogState {}

class VisitorLogSuccessState extends VisitorLogState {
  final List<VisitorLog>? visitorLogs;
  final int? currentPage;
  final int? lastPage;
  final bool? hasMoreData;

  VisitorLogSuccessState(
    this.visitorLogs, {
    this.currentPage,
    this.lastPage,
    this.hasMoreData,
  });
}

class VisitorCheckInLogSuccessState extends VisitorLogActionState {}

class VisitorCheckOutLogSuccessState extends VisitorLogActionState {}

class VisitorLogErrorState extends VisitorLogActionState {
  final String? message;

  VisitorLogErrorState(this.message);
}

class VisitorLogLoadingMoreState extends VisitorLogState {}

class VisitorLogCheckOutSuccessState extends VisitorLogActionState {
  final bool? isCheckOut;

  VisitorLogCheckOutSuccessState(this.isCheckOut);
}
