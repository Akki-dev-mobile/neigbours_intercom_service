import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_onegate/domain/entities/society/member_unit.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/utils/app_utils.dart';
import 'package:meta/meta.dart';
import 'package:onegate_client/onegate_client.dart';

part 'request_permission_event.dart';
part 'request_permission_state.dart';

class RequestPermissionBloc
    extends Bloc<RequestPermissionEvent, RequestPermissionState> {
  final VisitorLogUsecase visitorLogUsecase;
  RequestPermissionBloc(this.visitorLogUsecase)
      : super(RequestPermissionInitial()) {
    on<AllowButtonClickedEvent>(allowButtonClickedEvent);
  }

  FutureOr<void> allowButtonClickedEvent(AllowButtonClickedEvent event,
      Emitter<RequestPermissionState> emit) async {
    try {
      List<BuildingAssignment> buildingAssignments =
          createBuildingAssignments(event.memberUnits,412);
      for (BuildingAssignment buildingAssignment in buildingAssignments) {
        buildingAssignment.visitor_id = event.visitor.id;
      }
      print("${Utils.getCurrentTime().toUtc().toString()}");
      VisitorLog visitorLog = VisitorLog(
          company_id: 412,
          visitor_building_assignment: buildingAssignments,
          visitor_id: event.visitor.id!,
          visitor_count: event.guestCount == null ? 1 : event.guestCount!,
          visitor_purpose_category_id: event.purposeCategory.id!,
          visitor_check_in: Utils.getCurrentTime().toUtc(),
          visitor_coming_from: event.comingFrom,
          visitor: event.visitor,
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
      List<MemberUnits> memberUnits,int companyId) {
    List<BuildingAssignment> buildingAssignments = [];

    // Create a map to store the building IDs and their respective units
    Map<int, List<String>> buildingUnitsMap = {};

    // Iterate over the memberUnits list
    for (MemberUnits memberUnit in memberUnits) {
      int buildingId = memberUnit.socBuildingId;
      String unitId = memberUnit.unitFlatNumber;

      // Check if the building ID already exists in the map
      if (buildingUnitsMap.containsKey(buildingId)) {
        // Add the unit ID to the existing building's unit list
        buildingUnitsMap[buildingId]!.add(unitId);
      } else {
        // Create a new entry in the map for the building ID and its unit list
        buildingUnitsMap[buildingId] = [unitId];
      }
    }

    // Iterate over the buildingUnitsMap to create BuildingAssignment objects
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
