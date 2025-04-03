import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/repositories/license_plate_repository.dart';

part 'license_plate_event.dart';
part 'license_plate_state.dart';

class LicensePlateBloc extends Bloc<LicensePlateEvent, LicensePlateState> {
  final LicensePlateRepository repository;

  LicensePlateBloc(this.repository) : super(LicensePlateInitial()) {
    on<UploadImageEvent>(_onUploadImage);
  }

  void _onUploadImage(
      UploadImageEvent event, Emitter<LicensePlateState> emit) async {
    emit(LicensePlateLoading());
    try {
      final text = await repository.detectLicensePlate(event.imageFile);
      emit(LicensePlateSuccess(text));
    } catch (e) {
      emit(LicensePlateFailure(e.toString()));
    }
  }
}
