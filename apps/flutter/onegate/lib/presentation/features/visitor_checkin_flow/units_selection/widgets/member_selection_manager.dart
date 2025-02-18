import 'dart:developer';
import 'package:flutter/material.dart';

class MemberSelectionManager {
  final ValueNotifier<Set<String>> selectedMembersNotifier;
  final ValueNotifier<Set<int>> selectedUnitsNotifier;

  final Set<String> selectedUserIds = {};
  final List<int> selectedMemberIds = [];
  final List<String> selectedBuildingUnits = [];
  final List<Map<String, dynamic>> formattedMemberDetails = [];
  final Set<String> selectedMobileNumbers = {};

  MemberSelectionManager({
    required this.selectedMembersNotifier,
    required this.selectedUnitsNotifier,
  });

  Future<void> handleMemberSelection({
    required String firstName,
    required String userId,
    required dynamic memberId,
    required String buildingUnit,
    required dynamic unitId,
    String? memberMobileNo,
  }) async {
    final updatedMembers = Set<String>.from(selectedMembersNotifier.value);

    if (selectedMembersNotifier.value.contains(firstName)) {
      updatedMembers.remove(firstName);
      selectedUserIds.remove(userId);
      _removeMemberId(memberId);
      _removeMobileNumber(memberMobileNo);
      selectedBuildingUnits.remove(buildingUnit);
      formattedMemberDetails
          .removeWhere((member) => member["name"] == firstName);
    } else {
      updatedMembers.add(firstName);
      selectedUserIds.add(userId);
      _addSingleMemberId(memberId);
      _addSingleMobileNumber(memberMobileNo);
      selectedBuildingUnits.add(buildingUnit);

      formattedMemberDetails.add({
        "name": firstName,
        "unit_id": unitId,
        "member_ids": memberId,
        "building_unit": buildingUnit,
        "mobile_number": memberMobileNo,
      });
    }

    selectedMembersNotifier.value = updatedMembers;
    _updateSelectedUnits(unitId);
  }

  // PRIVATE HELPERS

  void _addSingleMobileNumber(String? memberMobileNo) {
    if (memberMobileNo != null && memberMobileNo.isNotEmpty) {
      selectedMobileNumbers.add(memberMobileNo);
    }
  }

  void _removeMobileNumber(String? memberMobileNo) {
    if (memberMobileNo != null && memberMobileNo.isNotEmpty) {
      selectedMobileNumbers.remove(memberMobileNo);
    }
  }

  void _addSingleMemberId(dynamic memberId) {
    if (memberId != null) {
      final idList = memberId.toString().split(',').map((id) => id.trim());
      for (final id in idList) {
        if (id.isNotEmpty) {
          try {
            int parsedId = int.parse(id);
            if (!selectedMemberIds.contains(parsedId)) {
              selectedMemberIds.add(parsedId);
            }
          } catch (e) {
            log("Error parsing member ID: $id, Error: $e");
          }
        }
      }
    }
  }

  void _removeMemberId(dynamic memberId) {
    if (memberId != null) {
      final idList = memberId.toString().split(',').map((id) => id.trim());
      for (final id in idList) {
        if (id.isNotEmpty) {
          try {
            int parsedId = int.parse(id);
            selectedMemberIds.remove(parsedId);
          } catch (e) {
            log("Error removing member ID: $id, Error: $e");
          }
        }
      }
    }
  }

  void _updateSelectedUnits(dynamic unitId) {
    final updatedUnits = Set<int>.from(selectedUnitsNotifier.value);
    if (updatedUnits.contains(unitId)) {
      updatedUnits.remove(unitId);
    } else {
      updatedUnits.add(unitId);
    }
    selectedUnitsNotifier.value = updatedUnits;
  }
}
