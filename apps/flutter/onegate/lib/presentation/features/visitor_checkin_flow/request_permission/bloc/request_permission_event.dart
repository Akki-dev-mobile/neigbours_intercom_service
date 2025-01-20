part of 'request_permission_bloc.dart';

@immutable
abstract class RequestPermissionEvent {}

class RequestPermissionInitialEvent extends RequestPermissionEvent {}

class AllowButtonClickedEvent extends RequestPermissionEvent{
    final Visitor visitor;
  final List<MemberUnits> memberUnits;
  final String? comingFrom;
  final int? guestCount;
  final PurposeCategory1 purposeCategory;

  AllowButtonClickedEvent({required this.visitor, required this.memberUnits, required this.comingFrom, required this.guestCount, required this.purposeCategory});
}
