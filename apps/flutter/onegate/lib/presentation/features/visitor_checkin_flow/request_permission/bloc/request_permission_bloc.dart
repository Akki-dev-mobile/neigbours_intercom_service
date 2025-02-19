import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/society/member_unit.dart';
import 'package:flutter_onegate/domain/entities/visitor/building_assignment.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/utils/app_utils.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLogMapper.dart';

part 'request_permission_event.dart';
part 'request_permission_state.dart';

class RequestPermissionBloc
    extends Bloc<RequestPermissionEvent, RequestPermissionState> {
  final VisitorLogUsecase visitorLogUsecase;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  RequestPermissionBloc(this.visitorLogUsecase)
      : super(RequestPermissionInitial()) {
    on<AllowButtonClickedEvent>(allowButtonClickedEvent);
  }

  FutureOr<void> allowButtonClickedEvent(AllowButtonClickedEvent event,
      Emitter<RequestPermissionState> emit) async {
    try {
      List<BuildingAssignment> buildingAssignments = createBuildingAssignments(
          event.memberUnits,
          _preferenceUtils.getSelectedCompany()?.companyId ?? 0);
      for (BuildingAssignment buildingAssignment in buildingAssignments) {
        buildingAssignment.visitor_id = event.visitor.id;
      }
      VisitorLog visitorLog = VisitorLog(
          company_id: _preferenceUtils.getSelectedCompany()?.companyId ?? 0,
          // visitorBu: buildingAssignments,
          visitor_id: event.visitor.id!,
          visitor_count: event.guestCount == null ? 1 : event.guestCount!,
          visitor_purpose_category_id: event.purposeCategory.categoryId,
          visitor_check_in: Utils.getCurrentTime().toUtc(),
          visitor_coming_from: event.comingFrom,
          // vi: event.visitor,
          is_checked_out: false);

      await visitorLogUsecase.createVisitorLog(visitorLog);

      emit(RequestPermissionInitial());
      emit(RPVisitorCheckedInSuccessState());
    } catch (e) {
      print(e.toString());
      emit(RPErrorState(message: e.toString()));
    }
  }

  List<BuildingAssignment> createBuildingAssignments(
      List<MemberUnits> memberUnits, int companyId) {
    List<BuildingAssignment> buildingAssignments = [];

    Map<int, List<String>> buildingUnitsMap = {};

    for (MemberUnits memberUnit in memberUnits) {
      int buildingId = memberUnit.socBuildingId ?? 0;
      String unitId = memberUnit.unitFlatNumber;

      if (buildingUnitsMap.containsKey(buildingId)) {
        buildingUnitsMap[buildingId]!.add(unitId);
      } else {
        buildingUnitsMap[buildingId] = [unitId];
      }
    }

    buildingUnitsMap.forEach((buildingId, unitIds) {
      BuildingAssignment buildingAssignment = BuildingAssignment(
        building_id: buildingId,
        unit_id: unitIds,
        company_id: companyId,
      );

      buildingAssignments.add(buildingAssignment);
    });

    return buildingAssignments;
  }
}
