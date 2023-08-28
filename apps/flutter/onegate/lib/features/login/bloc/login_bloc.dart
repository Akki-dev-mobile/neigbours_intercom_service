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
    on<AdminRoleSelectionButtonEvent>(adminRoleSelectionButtonEvent);
    on<GateKeeperRoleSelectionButtonEvent>(gateKeeperRoleSelectionButtonEvent);
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
      SocietySelectionButtonEvent event, Emitter<LoginState> emit) {
    print("societySelectionButtonEvent");
    emit(
      SocietySelectionButtonPressedState(),
    );
  }

  FutureOr<void> adminRoleSelectionButtonEvent(
      AdminRoleSelectionButtonEvent event, Emitter<LoginState> emit) {
    print("adminRoleSelectionButtonEvent");
    emit(
      AdminRoleSelectionButtonPressedState(),
    );
  }

  FutureOr<void> gateKeeperRoleSelectionButtonEvent(
      GateKeeperRoleSelectionButtonEvent event, Emitter<LoginState> emit) {
    print("gateKeeperRoleSelectionButtonEvent");
    emit(
      GatekeeperRoleSelectionButtonPressedState(),
    );
  }
}
