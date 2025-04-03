part of 'license_plate_bloc.dart';

abstract class LicensePlateEvent {}

class UploadImageEvent extends LicensePlateEvent {
  final File imageFile;

  UploadImageEvent(this.imageFile);
}
