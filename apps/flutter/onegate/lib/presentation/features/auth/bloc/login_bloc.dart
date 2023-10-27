import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/entities/auth/access_token_response.dart';
import 'package:flutter_onegate/domain/entities/auth/company.dart';
import 'package:flutter_onegate/domain/entities/gate/gate2.dart';
import 'package:flutter_onegate/domain/use_cases/auth_usecase.dart';
import 'package:flutter_onegate/domain/use_cases/gate_usecase.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';

part 'login_event.dart';

part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginUseCase _loginUseCase;
  final GateUseCase _gateUseCase;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();

  LoginBloc(this._loginUseCase, this._gateUseCase) : super(LoginInitial()) {
    on<LoginInitialEvent>(loginInitialEvent);
    on<LoginButtonPressedEvent>(loginButtonPressedEvent);
    on<SignUpButtonPressedEvent>(signUpButtonPressedEvent);
    on<ForgotPasswordButtonPressedEvent>(forgotPasswordButtonPressedEvent);
    on<SocietySelectionButtonEvent>(societySelectionButtonEvent);
    on<RoleSelectionButtonPressedEvent>(roleSelectionButtonPressedEvent);
    on<GateSelectionButtonPressedEvent>(gateSelectionButtonPressedEvent);
  }

  FutureOr<void> loginButtonPressedEvent(
      LoginButtonPressedEvent event, Emitter<LoginState> emit) async {
    print("loginButtonPressedEvent");
    emit(LoginLoadingState());
    try {
      final response = await _loginUseCase.login(
          event.username, event.password, "loginPassword");
      onSuccess(response, emit, _preferenceUtils);
    } catch (e) {
      print(e.toString());
      emit(
        LoginErrorState(
          message: e.toString(),
        ),
      );
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
      SocietySelectionButtonEvent event, Emitter<LoginState> emit) {
    _preferenceUtils.saveSelectedCompany(event.company);
    // emit(
    //   RoleSelectionState(_preferenceUtils.getRoles()),
    // );
    Company selectedCompany = _preferenceUtils.getSelectedCompany()!;
    final List<String> roles = [];
    for (final app in selectedCompany.apps) {
      roles.addAll(app.roles);
    }
    _preferenceUtils.saveRoles(roles);
    if (roles.contains("master")) {
      emit(RoleSelectionState(roles));
    } else if (roles.contains("gatekeeper")) {
      if (_preferenceUtils.getUserInfo()!.userId ==
          _preferenceUtils.getSelectedGate()!.userId) {
        emit(NavigateToGatekeeperDashboardState());
      } else {
        emit(LoginErrorState(message: "Gate Mismatch: Reach out to admin for gate correction."));
      }
    } else {
      emit(NavigateToAdminDashboardState());
    }
  }

  FutureOr<void> loginInitialEvent(
      LoginInitialEvent event, Emitter<LoginState> emit) {
    emit(LoginInitial());
  }

  FutureOr<void> roleSelectionButtonPressedEvent(
      RoleSelectionButtonPressedEvent event, Emitter<LoginState> emit) async {
    try {
      _preferenceUtils.setIsAdmin(event.isAdmin);
      if (event.isAdmin) {
        final List<Gate> gates = await _preferenceUtils.getGatesList();
        if (gates.isEmpty) {
          emit(LoginLoadingState());
          final response = await _gateUseCase
              .gateList(_preferenceUtils.getSelectedCompany()!.companyId);
          final List<Gate> gates = response!;
          emit(LoginInitial());
          if (response.length == 1) {
            _preferenceUtils.setSelectedGate(response[0]);
            _preferenceUtils.setIsLogin(true);
            emit(NavigateToAdminDashboardState());
            return;
          } else {
            emit(GateSelectionState(gates));
          }
        } else {
          _preferenceUtils.setIsLogin(true);
          emit(NavigateToAdminDashboardState());
        }
      } else {
        Gate? selectedGate = _preferenceUtils.getSelectedGate();
        if (selectedGate != null) {
          _preferenceUtils.setIsLogin(true);
          if (_preferenceUtils.getUserInfo()!.userId ==
              _preferenceUtils.getSelectedGate()!.userId) {
            emit(NavigateToGatekeeperDashboardState());
          } else {
            emit(LoginErrorState(message: "Gate Mismatch: Reach out to admin for gate correction."));
          }
        } else {
          emit(LoginErrorState(message: "Please info admin to select gate"));
        }
      }
    } catch (e) {
      emit(LoginErrorState(message: e.toString()));
    }

    //emit(RoleSelectionState(_preferenceUtils.getRoles()));
  }

  FutureOr<void> gateSelectionButtonPressedEvent(
      GateSelectionButtonPressedEvent event, Emitter<LoginState> emit) {
    _preferenceUtils.setSelectedGate(event.gate);
    if (_preferenceUtils.getIsAdmin()!) {
      emit(NavigateToAdminDashboardState());
    } else {
      if (_preferenceUtils.getUserInfo()!.userId ==
          _preferenceUtils.getSelectedGate()!.userId) {
        emit(NavigateToGatekeeperDashboardState());
      } else {
        emit(LoginErrorState(message: "Gate Mismatch: Reach out to admin for gate correction."));
      }
    }
  }

  void onSuccess(AccessTokenResponse? response, Emitter<LoginState> emit,
      PreferenceUtils preferenceUtils) {
    try {
      final List<Company> companiesWithAccessToGate = [];

      response!.userInfo.companies.forEach((key, companyList) {
        final filteredCompanies = companyList
            .where((company) => company.accessTo.contains(5))
            .toList();
        companiesWithAccessToGate.addAll(filteredCompanies);
      });

      preferenceUtils.saveAccessTokenResponse(response);
      preferenceUtils.saveUserInfo(response.userInfo);
      emit(LoginInitial());
      if (preferenceUtils.getSelectedCompany() == null) {
        emit(SocietySelectionState(companiesWithAccessToGate));
      } else {
        Company selectedCompany = preferenceUtils.getSelectedCompany()!;
        final List<String> roles = [];
        for (final app in selectedCompany.apps) {
          roles.addAll(app.roles);
        }
        preferenceUtils.saveRoles(roles);
        if (roles.contains("master")) {
          emit(RoleSelectionState(roles));
        } else if (roles.contains("gatekeeper")) {
          _preferenceUtils.setIsLogin(true);
          if (_preferenceUtils.getUserInfo()!.userId ==
              _preferenceUtils.getSelectedGate()!.userId) {
            emit(NavigateToGatekeeperDashboardState());
          } else {
            emit(LoginErrorState(message: "Gate Mismatch: Reach out to admin for gate correction."));
          }
        } else {
          emit(NavigateToAdminDashboardState());
        }
      }
    } catch (e) {
      emit(LoginInitial());
      emit(LoginErrorState(message: e.toString()));
    }
  }
}
