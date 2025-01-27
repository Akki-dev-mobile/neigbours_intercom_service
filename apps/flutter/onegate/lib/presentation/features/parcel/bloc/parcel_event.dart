part of 'parcel_bloc.dart';

abstract class ParcelEvent extends Equatable {
  const ParcelEvent();

  @override
  List<Object> get props => [];
}

class FetchParcels extends ParcelEvent {}
