part of 'reset_password_bloc.dart';

@immutable
sealed class ResetPasswordEvent {}

class ResetPasswordButtonPressedEvent extends ResetPasswordEvent {}
