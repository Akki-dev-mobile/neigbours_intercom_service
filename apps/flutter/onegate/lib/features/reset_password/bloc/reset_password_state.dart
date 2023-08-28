part of 'reset_password_bloc.dart';

@immutable
sealed class ResetPasswordState {}

abstract class ResetPasswordActionState extends ResetPasswordState {}

final class ResetPasswordInitial extends ResetPasswordState {}

class ResetPasswordButtonPressedState extends ResetPasswordActionState {}
