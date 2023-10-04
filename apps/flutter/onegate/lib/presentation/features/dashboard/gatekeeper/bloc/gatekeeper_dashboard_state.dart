part of 'gatekeeper_dashboard_bloc.dart';

@immutable
class GatekeeperDashboardState {}

abstract class GatekeeperDashboardActionState
    extends GatekeeperDashboardState {}

class GatekeeperDashboardInitial extends GatekeeperDashboardState {}

class GatekeeperDashboardLoadingState extends GatekeeperDashboardState {}

class GatekeeperDashboardSuccessState extends GatekeeperDashboardActionState {}

class GatekeeperDashboardErrorState extends GatekeeperDashboardActionState {
  final String? message;

  GatekeeperDashboardErrorState({this.message});
}
