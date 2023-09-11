part of 'admin_dashboard_bloc.dart';

@immutable
class AdminDashboardState {}
abstract class AdminDashboardActionState extends AdminDashboardState {}

class AdminDashboardInitial extends AdminDashboardState {}

class NavigateToSettingsState extends AdminDashboardActionState {}
