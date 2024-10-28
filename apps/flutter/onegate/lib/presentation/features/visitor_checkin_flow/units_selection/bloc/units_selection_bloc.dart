import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/entities/society/building.dart';
import 'package:flutter_onegate/domain/entities/society/member.dart';
import 'package:flutter_onegate/domain/entities/society/member_unit.dart';
import 'package:flutter_onegate/domain/use_cases/society_usecase.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';

part 'units_selection_event.dart';
part 'units_selection_state.dart';

class UnitsSelectionBloc extends Bloc<UnitSelectionEvent, UnitsSelectionState> {
  final SocietyUseCase societyUseCase;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  UnitsSelectionBloc(this.societyUseCase) : super(UnitsSelectionInitial()) {
    on<UnitSelectionInitialEvent>(unitSelectionInitialEvent);
    on<BuildingChipClickedEvent>(buildingChipClickedEvent);
    on<UnitSelectedEvent>(unitSelectedEvent);
    on<NextButtonClickedEvent>(nextButtonClickedEvent);
  }

  FutureOr<void> unitSelectionInitialEvent(UnitSelectionInitialEvent event,
      Emitter<UnitsSelectionState> emit) async {
    emit(UnitsSelectionLoadingState());
    try {
      List<Building>? buildings = await societyUseCase
          .getBuildings(_preferenceUtils.getSelectedCompany()!.companyId);
      if (buildings != null) {
        List<MemberUnits>? units = await societyUseCase.getUnits(
            _preferenceUtils.getSelectedCompany()!.companyId,
            buildings[0].id ?? 1);
        emit(UnitSelectionSuccessState(buildings[0],
            units: units, buildings: buildings));
      } else {
        emit(UnitsSelectionErrorState(message: "Error"));
      }
    } catch (e) {
      print(e.toString());
      emit(UnitsSelectionErrorState(message: e.toString()));
    }
  }

  FutureOr<void> buildingChipClickedEvent(
      BuildingChipClickedEvent event, Emitter<UnitsSelectionState> emit) async {
    emit(UnitsSelectionLoadingState());
    try {
      List<MemberUnits>? units = await societyUseCase.getUnits(
          _preferenceUtils.getSelectedCompany()!.companyId,
          event.building.id ?? 1);
      emit(UnitSelectionSuccessState(event.building,
          units: units, buildings: event.buildings));
    } catch (e) {
      print(e.toString());
      emit(UnitsSelectionErrorState(message: e.toString()));
    }
  }

  FutureOr<void> unitSelectedEvent(
      UnitSelectedEvent event, Emitter<UnitsSelectionState> emit) async {
    try {
      List<Member>? member = await societyUseCase.getMembers(
          _preferenceUtils.getSelectedCompany()!.companyId, event.unit.id ?? 1);
      if (member != null) {
        emit(MemberFetchedState(member));
      } else {
        emit(UnitsSelectionErrorState(message: "Error"));
      }
    } catch (e) {
      print(e.toString());
      emit(UnitsSelectionErrorState(message: e.toString()));
    }
  }

  FutureOr<void> nextButtonClickedEvent(
      NextButtonClickedEvent event, Emitter<UnitsSelectionState> emit) async {
    emit(UnitsSelectionLoadingState());
    try {
      emit(NavigateToRequestPermissionState(unit: event.unit));
    } catch (e) {
      print(e.toString());
      emit(UnitsSelectionErrorState(message: e.toString()));
    }
  }
}
