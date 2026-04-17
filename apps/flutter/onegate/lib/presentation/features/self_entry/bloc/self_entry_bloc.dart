import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_onegate/main.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:meta/meta.dart';

import '../../../../domain/entities/visitor/purpose/purpose.dart';

part 'self_entry_event.dart';
part 'self_entry_state.dart';

String _tr(String key, {Map<String, String>? params}) {
  final context = navigatorKey.currentContext;
  if (context == null) return key;
  return FlutterI18n.translate(context, key, translationParams: params);
}

class SelfEntryBloc extends Bloc<SelfEntryEvent, SelfEntryState> {
  final VisitorUsecase _visitorUsecase;

  SelfEntryBloc(this._visitorUsecase) : super(SelfEntryInitial()) {
    on<SEOnMobileNumberEnteredEvent>(seOnMobileNumberEnteredEvent);
    on<SEVerifyOtpEvent>(seVerifyOtpEvent);
  }

  FutureOr<void> seOnMobileNumberEnteredEvent(
      SEOnMobileNumberEnteredEvent event, Emitter<SelfEntryState> emit) async {
    try {
      final response = await _visitorUsecase.searchVisitor(event.mobileNumber);
      if (response != null) {
        emit(SESaveVisitorState(visitor: response));
      } else {
        final otpResponse = await _visitorUsecase.sendOTP(event.mobileNumber);
        if (otpResponse != null) {
          emit(SENavigateToOTPState(otpResponse,
              mobileNumber: event.mobileNumber));
        } else {
          emit(
            SelfEntryErrorState(
              message: _tr('Something went wrong'),
            ),
          );
        }
      }
    } catch (e) {
      print(e.toString());
      emit(
        SelfEntryErrorState(
          message: e.toString(),
        ),
      );
    }
  }

  FutureOr<void> seVerifyOtpEvent(
      SEVerifyOtpEvent event, Emitter<SelfEntryState> emit) async {
    try {
      final response =
          await _visitorUsecase.verifyOTP(event.mobileNumber, event.otp);

      if (response != null) {
        emit(SEOtpVerfiedState(mobileNumber: event.mobileNumber));
        emit(SelfEntryErrorState(message: response));
      } else {
        emit(
          SelfEntryErrorState(
            message: _tr('Something went wrong'),
          ),
        );
      }
    } catch (e) {
      print(e.toString());
      emit(
        SelfEntryErrorState(
          message: e.toString(),
        ),
      );
    }
  }
}
