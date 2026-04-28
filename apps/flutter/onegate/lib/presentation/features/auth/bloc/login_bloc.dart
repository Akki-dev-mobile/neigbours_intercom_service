import 'dart:async';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/domain/entities/auth/access_token_response.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/notifications/push_notification_service.dart';
import 'package:flutter_onegate/domain/entities/auth/company.dart';
import 'package:flutter_onegate/domain/entities/gate/gate2.dart';
import 'package:flutter_onegate/domain/use_cases/auth_usecase.dart';
import 'package:flutter_onegate/domain/use_cases/gate_usecase.dart';
import 'package:flutter_onegate/main.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';

part 'login_event.dart';

part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginUseCase _loginUseCase;
  final GateUseCase _gateUseCase;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  bool _isLoginInProgress = false;

  String _tr(String key, {Map<String, String>? params}) {
    final context = navigatorKey.currentContext;
    if (context == null) return key;
    return FlutterI18n.translate(context, key, translationParams: params);
  }

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
    if (_isLoginInProgress) {
      log("loginButtonPressedEvent ignored: login already in progress");
      return;
    }

    _isLoginInProgress = true;
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
    } finally {
      _isLoginInProgress = false;
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
      SocietySelectionButtonEvent event, Emitter<LoginState> emit) async {
    _preferenceUtils.saveSelectedCompany(event.company);
    final Company selectedCompany = _preferenceUtils.getSelectedCompany()!;

    // Save society id to GateStorage so fetchGates() can load gates for this society
    final societyId = selectedCompany.companyId?.toString() ?? '';
    if (societyId.isNotEmpty) {
      await GateStorage().saveSocietyDetails(
        societyId,
        selectedCompany.companyName,
      );
    }
    // Clear cached gates so next role selection fetches gates for this society
    await _preferenceUtils.saveGatesList([]);

    // Prefer user_roles from gate API (e.g. [master, gatekeeper]); fallback to apps[].roles
    List<String> roles = selectedCompany.userRoles ?? [];
    if (roles.isEmpty) {
      for (final app in selectedCompany.apps ?? []) {
        roles.addAll(app.roles ?? []);
      }
    }
    // Map master -> admin for role selection sheet (Admin / Gatekeeper)
    roles =
        roles.map((r) => r.toLowerCase() == 'master' ? 'admin' : r).toList();
    _preferenceUtils.saveRoles(roles);

    if (roles.contains('master') || roles.contains('admin')) {
      emit(RoleSelectionState(roles));
    } else if (roles.contains('gatekeeper')) {
      emit(NavigateToGatekeeperDashboardState());
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
      final companyId = _preferenceUtils.getSelectedCompany()?.companyId ?? 0;
      if (event.isAdmin) {
        final List<Gate> gates = await _preferenceUtils.getGatesList();
        if (gates.isEmpty) {
          emit(LoginNavigationLoadingState());
          final response = await _gateUseCase.gateList(companyId);
          final List<Gate> gates = response ?? [];
          print(
              "Company Selected Gate IDDD: ${_preferenceUtils.getSelectedCompany()}");
          print("Company Selected Gate IDDD Response: $response");
          print("Company Selected Gate IDDD Gates: $gates");
          print("Company Selected Gate IDDD Gates length: $gates.length");
          print(
              "Company Selected Gate IDDD Gates toString: ${gates.toString()}");
          for (var gate in gates) {
            print("Company Selected Gate loop: $gate");
          }

          emit(LoginInitial());
          if (gates.length == 1) {
            await _preferenceUtils.setSelectedGate(gates[0]);
            _preferenceUtils.setIsLogin(true);
            await GateStorage().saveRole('admin');
            emit(NavigateToAdminDashboardState());
            return;
          } else if (gates.isEmpty) {
            emit(LoginErrorState(
                message: _tr("No gates found for this society")));
            return;
          } else {
            await _preferenceUtils.saveGatesList(gates);
            emit(GateSelectionState(gates));
          }
        } else {
          final hasSelectedGate = await _ensureSelectedGate(gates);
          if (!hasSelectedGate) {
            emit(GateSelectionState(gates));
            return;
          }
          _preferenceUtils.setIsLogin(true);
          await GateStorage().saveRole('admin');
          emit(NavigateToAdminDashboardState());
        }
      } else {
        // Gatekeeper: fetch gates and show gate selection
        final List<Gate> existingGates = await _preferenceUtils.getGatesList();
        if (existingGates.isEmpty) {
          emit(LoginNavigationLoadingState());
          final response = await _gateUseCase.gateList(companyId);
          final List<Gate> gateList = response ?? [];
          emit(LoginInitial());
          if (gateList.isEmpty) {
            emit(LoginErrorState(
                message: _tr("No gates found for this society")));
            return;
          }
          await _preferenceUtils.saveGatesList(gateList);
          if (gateList.length == 1) {
            await _preferenceUtils.setSelectedGate(gateList[0]);
            _preferenceUtils.setIsLogin(true);
            await GateStorage().saveRole('gatekeeper');
            emit(NavigateToGatekeeperDashboardState());
            return;
          }
          emit(GateSelectionState(gateList));
        } else {
          final hasSelectedGate = await _ensureSelectedGate(existingGates);
          if (!hasSelectedGate) {
            emit(GateSelectionState(existingGates));
            return;
          }
          _preferenceUtils.setIsLogin(true);
          await GateStorage().saveRole('gatekeeper');
          emit(NavigateToGatekeeperDashboardState());
        }
      }
    } catch (e) {
      emit(LoginErrorState(message: e.toString()));
    }

    //emit(RoleSelectionState(_preferenceUtils.getRoles()));
  }

  FutureOr<void> gateSelectionButtonPressedEvent(
      GateSelectionButtonPressedEvent event, Emitter<LoginState> emit) async {
    await _preferenceUtils.setSelectedGate(event.gate);
    if (_preferenceUtils.getIsAdmin()!) {
      await GateStorage().saveRole('admin');
      emit(NavigateToAdminDashboardState());
    } else {
      final matches = await _userMatchesSelectedGate();
      if (matches) {
        _preferenceUtils.setIsLogin(true);
        await GateStorage().saveRole('gatekeeper');
        emit(NavigateToGatekeeperDashboardState());
      } else {
        emit(LoginErrorState(
            message:
                _tr("Gate Mismatch: Reach out to admin for gate correction.")));
      }
    }
  }

  Future<bool> _ensureSelectedGate(List<Gate> gates) async {
    final selectedGate = _preferenceUtils.getSelectedGate();
    if (selectedGate != null) return true;

    final storedGate = await GateStorage().getSelectedGate();
    final storedGateName = storedGate['name']?.trim();
    if (storedGateName != null &&
        storedGateName.isNotEmpty &&
        storedGateName.toLowerCase() != 'null') {
      for (final gate in gates) {
        if ((gate.gateName ?? '').trim().toLowerCase() ==
            storedGateName.toLowerCase()) {
          await _preferenceUtils.setSelectedGate(gate);
          return true;
        }
      }
    }

    if (gates.length == 1) {
      await _preferenceUtils.setSelectedGate(gates.first);
      return true;
    }

    return false;
  }

  Future<bool> _userMatchesSelectedGate() async {
    final gate = _preferenceUtils.getSelectedGate();
    if (gate == null) return false;

    final gateUserIdStr = _gateIdToString(gate.userId);
    final gateOldSsoStr = _gateIdToString(gate.oldSsoUserId);
    if (gateUserIdStr.isEmpty && gateOldSsoStr.isEmpty) return true;

    final userIds = <String>[];
    final userInfo = _preferenceUtils.getUserInfo();
    if (userInfo != null) {
      final u = userInfo.userId?.toString();
      final v = userInfo.uuid;
      if (u != null && u.isNotEmpty) userIds.add(u);
      if (v != null && v.isNotEmpty && !userIds.contains(v)) userIds.add(v);
    }
    if (userIds.isEmpty) {
      final stored = await GateStorage().getUserId();
      if (stored != null && stored.isNotEmpty) userIds.add(stored);
    }
    if (userIds.isEmpty) {
      final accessToken = await GateStorage().getAccessToken();
      if (accessToken != null) {
        final payload = JwtTokenUtility.parseJwtToken(accessToken);
        if (payload != null) {
          for (final key in ['old_gate_user_id', 'old_sso_user_id']) {
            final v = payload[key]?.toString();
            if (v != null && v.isNotEmpty && !userIds.contains(v)) {
              userIds.add(v);
            }
          }
        }
      }
    }
    if (userIds.isEmpty) return false;

    return userIds.any((id) => id == gateUserIdStr || id == gateOldSsoStr);
  }

  static String _gateIdToString(dynamic value) {
    if (value == null) return '';
    if (value is int) return value.toString();
    if (value is String) return value;
    return value.toString();
  }

  void onSuccess(AccessTokenResponse? response, Emitter<LoginState> emit,
      PreferenceUtils preferenceUtils) {
    try {
      var companiesWithAccessToGate = [];

// Iterate over the list of companies
      response!.userInfo?.companies?.forEach((key, companyList) {
        // Iterate over each company in the list
        companyList.forEach((company) {
          // Include companies with gate access (accessTo contains 5), or
          // when accessTo is null/empty (e.g. Keycloak + gate API societies)
          final hasGateAccess = company.accessTo == null ||
              company.accessTo!.isEmpty ||
              company.accessTo!.contains(5);
          if (hasGateAccess) {
            companiesWithAccessToGate.add(company);
          }
        });
      });
      preferenceUtils.saveAccessTokenResponse(response);
      // Ensure GateStorage has raw tokens (AuthRepositoryImpl already does this; this guards alternate flows)
      if (response.accessToken != null && response.accessToken!.isNotEmpty) {
        unawaited(GateStorage().saveAccessToken(response.accessToken!));
      }
      if (response.refresh_token != null &&
          response.refresh_token!.isNotEmpty) {
        unawaited(GateStorage().saveRefreshToken(response.refresh_token!));
      }
      if (response.userInfo != null) {
        preferenceUtils.saveUserInfo(response.userInfo!);
      } else {
        throw Exception("UserInfo is null");
      }
      // Fire-and-forget to avoid impacting login UX if notification setup fails.
      unawaited(PushNotificationService.syncCurrentTokenWithBackend());
      emit(LoginInitial());
      // Always show society list after login so user can pick society every time
      if (companiesWithAccessToGate.isEmpty) {
        emit(LoginErrorState(
            message: _tr("No societies found for your account.")));
      } else {
        emit(SocietySelectionState(companiesWithAccessToGate));
      }
    } catch (e) {
      emit(LoginInitial());
      emit(LoginErrorState(message: e.toString()));
    }
  }
}
