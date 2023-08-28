part of 'login_bloc.dart';

@immutable
sealed class LoginEvent {}

class LoginButtonPressedEvent extends LoginEvent {
  // final String username;
  // final String password;

  // LoginButtonPressed({
  //   required this.username,
  //   required this.password,
  // });
}

class SignUpButtonPressedEvent extends LoginEvent {}

class ForgotPasswordButtonPressedEvent extends LoginEvent {}

class SocietySelectionButtonEvent extends LoginEvent {
  // final String societyId;

  // SocietySelectedEvent({
  //   required this.societyId,
  // });
}

class AdminRoleSelectionButtonEvent extends LoginEvent {}

class GateKeeperRoleSelectionButtonEvent extends LoginEvent {}
