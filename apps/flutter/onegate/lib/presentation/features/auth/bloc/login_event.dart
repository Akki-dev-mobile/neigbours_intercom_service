part of 'login_bloc.dart';

@immutable
abstract class LoginEvent {}

class LoginInitialEvent extends LoginEvent {}

class LoginButtonPressedEvent extends LoginEvent {
  final String username;
  final String password;
  LoginButtonPressedEvent(this.username, this.password);
}

class SignUpButtonPressedEvent extends LoginEvent {}

class ForgotPasswordButtonPressedEvent extends LoginEvent {}

class SocietySelectionButtonEvent extends LoginEvent {
  final Company company;
  SocietySelectionButtonEvent(this.company);
}

class NavigateToGateSelectionEvent extends LoginEvent {}

class NavigateToAdminDashboardEvent extends LoginEvent {}

class NavigateToGatekeeperDashboardEvent extends LoginEvent {}

class RoleSelectionButtonPressedEvent extends LoginEvent {
  final bool isAdmin;
  RoleSelectionButtonPressedEvent(
    this.isAdmin,
  );
}

class HasOffineLoginButtonPressedEvent extends LoginEvent {
  // final bool hasOfflineLogin;
  // HasOffineLoginButtonPressedEvent({
  //   required this.hasOfflineLogin,
  // });
}

class NotHasOffineLoginButtonPressedEvent extends LoginEvent {}
