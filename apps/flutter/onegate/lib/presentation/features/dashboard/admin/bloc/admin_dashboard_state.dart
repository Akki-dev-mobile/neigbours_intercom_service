part of 'admin_dashboard_bloc.dart';

@immutable
abstract class AdminDashboardState {}

abstract class AdminDashboardActionState extends AdminDashboardState {}

class AdminDashboardInitial extends AdminDashboardState {}

class NavigateToSettingsState extends AdminDashboardActionState {}

class AdminDashboardLoadingState extends AdminDashboardState {}

class AdminDashboardErrorState extends AdminDashboardState {
  final String error;

  AdminDashboardErrorState({required this.error});
}

class AdminDashboardSuccessState extends AdminDashboardState {
  final int? inBook;
  final int? outBook;

  AdminDashboardSuccessState({required this.inBook, required this.outBook});
}

class ADInAndOutButtonPressedState extends AdminDashboardActionState {}

class ADVisitorsInButtonPressedState extends AdminDashboardActionState {}

class ADVisitorsOutButtonPressedState extends AdminDashboardActionState {}
