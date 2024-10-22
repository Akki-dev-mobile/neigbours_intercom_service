import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'reset_password_event.dart';
part 'reset_password_state.dart';

class ResetPasswordBloc extends Bloc<ResetPasswordEvent, ResetPasswordState> {
  ResetPasswordBloc() : super(ResetPasswordInitial()) {
    on<ResetPasswordButtonPressedEvent>(resetPasswordButtonPressedEvent);
  }

  FutureOr<void> resetPasswordButtonPressedEvent(
      ResetPasswordButtonPressedEvent event, Emitter<ResetPasswordState> emit) {
    print("resetPasswordButtonPressedEvent");
    emit(
      ResetPasswordButtonPressedState(),
    );
  }
}
