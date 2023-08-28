part of 'login_bloc.dart';

@immutable
sealed class LoginState {}

abstract class LoginActionState extends LoginState {}

final class LoginInitial extends LoginState {}

class LoginLoadingState extends LoginState {}

class LoginLoadingSuccessState extends LoginState {}

class LoginLoadingErrorState extends LoginState {}

class LoginButtonPressedState extends LoginActionState {}

class SignUpButtonPressedState extends LoginActionState {}

class ForgotPasswordButtonPressedState extends LoginActionState {}

class SocietySelectionButtonPressedState extends LoginActionState {}

class AdminRoleSelectionButtonPressedState extends LoginActionState {}

class GateKeeperRoleSelectionButtonPressedState extends LoginActionState {}

class HasOfflineLoginButtonPressedState extends LoginActionState {}

class NotHasOfflineLoginButtonPressedState extends LoginActionState {}
