part of 'request_permission_bloc.dart';

@immutable
class RequestPermissionState {}

class RequestPermissionInitial extends RequestPermissionState {}

class RequestPermissionActionState extends RequestPermissionState {}

class RPVisitorCheckedInSuccessState extends RequestPermissionActionState{}

class RPLoadingState extends RequestPermissionState {}

class RPErrorState extends RequestPermissionActionState {
  final String? message;

  RPErrorState({this.message});
}
