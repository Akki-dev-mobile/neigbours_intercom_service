part of 'login_bloc.dart';

@immutable
class LoginState {}

abstract class LoginActionState extends LoginState {}

class LoginInitial extends LoginState {}

class LoginLoadingState extends LoginState {}

class LoginNavigationLoadingState extends LoginState {}

class LoginSuccessState extends LoginActionState {
  final AccessTokenResponse? accessTokenResponse;
  final List<Company?> companiesWithAccessToGate;

  LoginSuccessState(this.accessTokenResponse, this.companiesWithAccessToGate);
}

class SocietySelectionState extends LoginActionState {
  var companiesWithAccessToGate;

  SocietySelectionState(this.companiesWithAccessToGate);
}

class GateSelectionState extends LoginActionState {
  final List<Gate?> gates;

  GateSelectionState(this.gates);
}

class RoleSelectionState extends LoginActionState {
  final List<String?> roles;

  RoleSelectionState(this.roles);
}

class LoginErrorState extends LoginActionState {
  final String? message;

  LoginErrorState({this.message});
}

class LoginButtonPressedState extends LoginActionState {}

class SignUpButtonPressedState extends LoginActionState {}

class ForgotPasswordButtonPressedState extends LoginActionState {}

class SocietySelectionButtonPressedState extends LoginActionState {}

class RoleSelectionButtonPressedState extends LoginActionState {}

class HasOfflineLoginButtonPressedState extends LoginActionState {}

class NotHasOfflineLoginButtonPressedState extends LoginActionState {}

class NavigateToAdminDashboardState extends LoginActionState {}

class NavigateToGatekeeperDashboardState extends LoginActionState {}
