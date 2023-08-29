import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/entities/access_token_response.dart';
import 'package:flutter_onegate/domain/entities/company.dart';
import 'package:flutter_onegate/domain/use_cases/auth_usecase.dart';
import 'package:meta/meta.dart';
part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
   final LoginUseCase _loginUseCase;
  LoginBloc(this._loginUseCase) : super(LoginInitial()) {
    on<LoginButtonPressedEvent>(loginButtonPressedEvent);
    on<SignUpButtonPressedEvent>(signUpButtonPressedEvent);
    on<ForgotPasswordButtonPressedEvent>(forgotPasswordButtonPressedEvent);
    on<SocietySelectionButtonEvent>(societySelectionButtonEvent);
  }
  FutureOr<void> loginButtonPressedEvent(
      LoginButtonPressedEvent event, Emitter<LoginState> emit) async{
    print("loginButtonPressedEvent");
    emit(LoginLoadingState());
    try{
      final response = await _loginUseCase.login(event.username!, event.password!, "loginPassword");
      onSuccess(response, emit);
    }catch(e){
      print(e.toString());
      emit(LoginLoadingErrorState());
    }
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

void onSuccess(AccessTokenResponse? response, Emitter<LoginState> emit) {
  if (response != null) {
    final List<Company> companiesWithAccessToGate = [];

  response.userInfo.companies.forEach((key, companyList) {
    final filteredCompanies = companyList.where((company) => company.accessTo.contains(5)).toList();
    companiesWithAccessToGate.addAll(filteredCompanies);
  });
  print("companiesWithAccessToGate: ${companiesWithAccessToGate.toString()}");
  emit(LoginLoadingSuccessState(response, companiesWithAccessToGate));
  } else {
    emit(LoginLoadingErrorState());
  }
}
