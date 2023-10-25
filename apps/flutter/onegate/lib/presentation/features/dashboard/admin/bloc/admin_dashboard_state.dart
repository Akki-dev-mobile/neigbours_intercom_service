part of 'admin_dashboard_bloc.dart';

@immutable
class AdminDashboardState {}

abstract class AdminDashboardActionState extends AdminDashboardState {}

class AdminDashboardInitial extends AdminDashboardState {}

class NavigateToSettingsState extends AdminDashboardActionState {}

class AdminDashboardLoadingState extends AdminDashboardActionState {}

class AdminDashboardSuccessState extends AdminDashboardState {
  final int? inBook;
  final int? outBook;

  AdminDashboardSuccessState({required this.inBook, required this.outBook});
}
