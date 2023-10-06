part of 'gatekeeper_dashboard_bloc.dart';

@immutable
 class GatekeeperDashboardState {}
 abstract class GatekeeperDashboardActionState extends GatekeeperDashboardState {}

class GatekeeperDashboardInitial extends GatekeeperDashboardState {}

class GatekeeperDashboardLoadingState extends GatekeeperDashboardState {}

class GatekeeperDashboardSuccessState extends GatekeeperDashboardActionState {}

class GatekeeperDashboardErrorState extends GatekeeperDashboardActionState {
  final String? message;

  GatekeeperDashboardErrorState({this.message});
}

class GDIntercomButtonPressedState extends GatekeeperDashboardActionState {}

class GDParcelButtonPressedState extends GatekeeperDashboardActionState {}

class GDScanButtonPressedState extends GatekeeperDashboardActionState {}

class GDInAndOutButtonPressedState extends GatekeeperDashboardActionState {}

class GDVisitorsInButtonPressedState extends GatekeeperDashboardActionState {}

class GDVisitorsOutButtonPressedState extends GatekeeperDashboardActionState {}

class GDInputFieldPressedState extends GatekeeperDashboardActionState {}

class GatekeeperSearchVisitorState extends GatekeeperDashboardState {}