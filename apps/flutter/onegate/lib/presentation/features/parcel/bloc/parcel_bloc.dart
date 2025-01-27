import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/presentation/features/parcel/bloc/parcel_state.dart';

part 'parcel_event.dart';

class ParcelBloc extends Bloc<ParcelEvent, ParcelState> {
  final RemoteDataSource remoteDataSource;

  ParcelBloc(this.remoteDataSource) : super(ParcelInitial()) {
    on<FetchParcels>(_onFetchParcels);
  }

  Future<void> _onFetchParcels(
      FetchParcels event, Emitter<ParcelState> emit) async {
    emit(ParcelLoading());
    try {
      final parcels = await remoteDataSource.fetchParcels();
      emit(ParcelLoaded(parcels));
    } catch (e) {
      emit(ParcelError(e.toString()));
    }
  }
}
