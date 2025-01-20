import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';

part 'self_entry_event.dart';
part 'self_entry_state.dart';

class SelfEntryBloc extends Bloc<SelfEntryEvent, SelfEntryState> {
  final VisitorUsecase _visitorUsecase;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
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
      }
      else {
        final otpResponse = await _visitorUsecase.sendOTP(event.mobileNumber);
        if (otpResponse != null) {
          emit(SENavigateToOTPState(otpResponse, mobileNumber: event.mobileNumber));
        } else {
          emit(
            SelfEntryErrorState(
              message: 'Something went wrong',
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

  FutureOr<void> seVerifyOtpEvent(SEVerifyOtpEvent event, Emitter<SelfEntryState> emit) async{
    try {
      final response = await _visitorUsecase.verifyOTP(event.mobileNumber, event.otp);
      
      if (response != null) {
        emit(SEOtpVerfiedState(mobileNumber: event.mobileNumber));
        emit(SelfEntryErrorState(message: response ));
      } else {
        emit(
          SelfEntryErrorState(
            message: 'Something went wrong',
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
