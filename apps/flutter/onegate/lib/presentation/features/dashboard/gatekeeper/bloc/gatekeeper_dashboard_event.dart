part of 'gatekeeper_dashboard_bloc.dart';

@immutable
abstract class GatekeeperDashboardEvent {}

class GatekeeperDashboardInitialEvent extends GatekeeperDashboardEvent {}

class GDJaateRaahoButtonPressedEvent extends GatekeeperDashboardEvent {}

class GDMissedApprovalsButtonPressedEvent extends GatekeeperDashboardEvent {}

class GDGateSettingsButtonPressedEvent extends GatekeeperDashboardEvent {}

class GDIntercomButtonPressedEvent extends GatekeeperDashboardEvent {}

class GDParcelButtonPressedEvent extends GatekeeperDashboardEvent {}

class GDScanButtonPressedEvent extends GatekeeperDashboardEvent {}

class GDInAndOutButtonPressedEvent extends GatekeeperDashboardEvent {}

class GDVisitorsInButtonPressedEvent extends GatekeeperDashboardEvent {}

class GDVisitorsOutButtonPressedEvent extends GatekeeperDashboardEvent {}

class GDOnMobileNumberEnteredEvent extends GatekeeperDashboardEvent {
  final String mobileNumber;

  GDOnMobileNumberEnteredEvent(this.mobileNumber);
}

class InputPutViewNextClickedEvent extends GatekeeperDashboardEvent {}

class PurposeNextButtonClickedEvent extends GatekeeperDashboardEvent {
  final PurposeCategory purpose;
  final VisitorMapper? searchedVisitor;
  final String mobile;

  PurposeNextButtonClickedEvent(this.purpose, this.searchedVisitor, this.mobile);
}

