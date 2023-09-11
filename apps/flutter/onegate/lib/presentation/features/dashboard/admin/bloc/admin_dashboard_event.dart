part of 'admin_dashboard_bloc.dart';

@immutable
abstract class AdminDashboardEvent {}

class AdminDashboardInitialEvent extends AdminDashboardEvent {}

class AdminDashboardSettingsPressedEvent extends AdminDashboardEvent {}
