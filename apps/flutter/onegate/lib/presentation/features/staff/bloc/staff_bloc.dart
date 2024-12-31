import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/domain/entities/staff/staff_entity.dart';

import '../../../../domain/repositories/staff_repository.dart';

abstract class StaffEvent {}

class LoadStaffEvent extends StaffEvent {
  final String companyId;

  LoadStaffEvent(this.companyId);
}

abstract class StaffState {}

class StaffInitialState extends StaffState {}

class StaffLoadingState extends StaffState {}

class StaffLoadedState extends StaffState {
  final List<StaffEntity> staffList;

  StaffLoadedState(this.staffList);
}

class StaffErrorState extends StaffState {
  final String message;

  StaffErrorState(this.message);
}

class StaffBloc extends Bloc<StaffEvent, StaffState> {
  final StaffRepository repository;

  StaffBloc(this.repository) : super(StaffInitialState()) {
    on<LoadStaffEvent>((event, emit) async {
      emit(StaffLoadingState());
      try {
        final staffList = await repository.getStaffList(event.companyId);
        emit(StaffLoadedState(staffList));
      } catch (e) {
        emit(StaffErrorState(e.toString()));
      }
    });
  }
}