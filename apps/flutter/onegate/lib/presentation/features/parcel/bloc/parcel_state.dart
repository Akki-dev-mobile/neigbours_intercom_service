import 'package:equatable/equatable.dart';

abstract class ParcelState extends Equatable {
  const ParcelState();

  @override
  List<Object> get props => [];
}

class ParcelInitial extends ParcelState {}

class ParcelLoading extends ParcelState {}

class ParcelLoaded extends ParcelState {
  final List<dynamic> parcels;

  const ParcelLoaded(this.parcels);

  @override
  List<Object> get props => [parcels];
}

class ParcelError extends ParcelState {
  final String message;

  const ParcelError(this.message);

  @override
  List<Object> get props => [message];
}
