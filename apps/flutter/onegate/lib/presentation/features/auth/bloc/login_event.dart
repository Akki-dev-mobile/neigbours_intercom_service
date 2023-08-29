part of 'login_bloc.dart';

@immutable
abstract class LoginEvent {}

class LoginButtonPressedEvent extends LoginEvent {
  final String username;
  final String password;

  LoginButtonPressedEvent(this.username, this.password);
  

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

class HasOffineLoginButtonPressedEvent extends LoginEvent {
  // final bool hasOfflineLogin;
  // HasOffineLoginButtonPressedEvent({
  //   required this.hasOfflineLogin,
  // });
}

class NotHasOffineLoginButtonPressedEvent extends LoginEvent {}
