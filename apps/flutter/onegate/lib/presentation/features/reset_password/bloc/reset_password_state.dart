part of 'reset_password_bloc.dart';

@immutable
class ResetPasswordState {}

abstract class ResetPasswordActionState extends ResetPasswordState {}

class ResetPasswordInitial extends ResetPasswordState {}

class ResetPasswordButtonPressedState extends ResetPasswordActionState {}
