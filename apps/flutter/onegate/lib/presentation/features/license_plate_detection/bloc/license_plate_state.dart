part of 'license_plate_bloc.dart';

abstract class LicensePlateState {}

class LicensePlateInitial extends LicensePlateState {}

class LicensePlateLoading extends LicensePlateState {}

class LicensePlateSuccess extends LicensePlateState {
  final String plateText;

  LicensePlateSuccess(this.plateText);
}

class LicensePlateFailure extends LicensePlateState {
  final String error;

  LicensePlateFailure(this.error);
}
