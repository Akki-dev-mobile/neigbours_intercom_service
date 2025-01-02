part of 'gatekeeper_dashboard_bloc.dart';

@immutable
class GatekeeperDashboardState {}

abstract class GatekeeperDashboardActionState
    extends GatekeeperDashboardState {}

class GatekeeperDashboardInitial extends GatekeeperDashboardState {}

class GatekeeperDashboardLoadingState extends GatekeeperDashboardState {}

class GatekeeperDashboardSuccessState extends GatekeeperDashboardState {
  final int? inBook;
  final int? outBook;

  GatekeeperDashboardSuccessState({
    required this.inBook,
    required this.outBook,
  });
}

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

class InputPutViewNextClickedState extends GatekeeperDashboardActionState {}

class OpenPurposeDialogState extends GatekeeperDashboardActionState {
  final List<PurposeCategory>? purposeCategories;

  OpenPurposeDialogState({required this.purposeCategories});
}

class SaveSearchedVisitorState extends GatekeeperDashboardActionState {
  final VisitorMapper? visitor;

  SaveSearchedVisitorState({required this.visitor});
}

class NavigateToVisitorDetailsState extends GatekeeperDashboardActionState {
  final VisitorMapper? visitor;
  final PurposeCategory purpose;
  final String mobile;

  NavigateToVisitorDetailsState(this.purpose, this.mobile,
      {required this.visitor});
}
