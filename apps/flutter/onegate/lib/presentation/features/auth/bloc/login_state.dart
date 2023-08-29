part of 'login_bloc.dart';

@immutable
sealed class LoginState {}

abstract class LoginActionState extends LoginState {}

final class LoginInitial extends LoginState {}

class LoginLoadingState extends LoginState {}

class LoginSuccessState extends LoginActionState {
  final AccessTokenResponse? accessTokenResponse;
  final List<Company?> companiesWithAccessToGate;

  LoginSuccessState(this.accessTokenResponse, this.companiesWithAccessToGate);

}

class LoginErrorState extends LoginState {}

class LoginButtonPressedState extends LoginActionState {}

class SignUpButtonPressedState extends LoginActionState {}

class ForgotPasswordButtonPressedState extends LoginActionState {}

class SocietySelectionButtonPressedState extends LoginActionState {}

class RoleSelectionButtonPressedState extends LoginActionState {}

class HasOfflineLoginButtonPressedState extends LoginActionState {}

class NotHasOfflineLoginButtonPressedState extends LoginActionState {}

class NavigateToGateSelectionState extends LoginActionState {}

class NavigateToAdminDashboardState extends LoginActionState {}
