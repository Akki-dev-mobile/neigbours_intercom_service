import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc() : super(LoginInitial()) {
    on<LoginButtonPressedEvent>(loginButtonPressedEvent);
    on<SignUpButtonPressedEvent>(signUpButtonPressedEvent);
    on<ForgotPasswordButtonPressedEvent>(forgotPasswordButtonPressedEvent);
    on<SocietySelectionButtonEvent>(societySelectionButtonEvent);
  }
  FutureOr<void> loginButtonPressedEvent(
      LoginButtonPressedEvent event, Emitter<LoginState> emit) {
    print("loginButtonPressedEvent");
    emit(
      LoginButtonPressedState(),
    );
  }

  FutureOr<void> signUpButtonPressedEvent(
      SignUpButtonPressedEvent event, Emitter<LoginState> emit) {
    print("signUpButtonPressedEvent");
    emit(
      SignUpButtonPressedState(),
    );
  }

  FutureOr<void> forgotPasswordButtonPressedEvent(
      ForgotPasswordButtonPressedEvent event, Emitter<LoginState> emit) {
    print("forgotPasswordButtonPressedEvent");
    emit(
      ForgotPasswordButtonPressedState(),
    );
  }

  FutureOr<void> societySelectionButtonEvent(
      SocietySelectionButtonEvent event, Emitter<LoginState> emit) {}
}
