import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import '../models/member_model.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UnitSelectionController {
  final Dio _dio = Dio();
  final GateStorage gateStorage = GateStorage();
  final RemoteDataSource remoteDataSource = RemoteDataSource();

  final ValueNotifier<List<dynamic>> filteredMembersNotifier =
      ValueNotifier([]);
  final ValueNotifier<Set<String>> selectedMembersNotifier = ValueNotifier({});
  final ValueNotifier<Set<int>> selectedUnitsNotifier = ValueNotifier({});

  List<dynamic> allMembers = [];
  String? companyId;
  String? companyName;
  Set<String> selectedUserIds = {};
  List<int> selectedMemberIds = [];
  List<String> selectedBuildingUnits = [];
  List<MemberModel> formattedMemberDetails = [];

  Future<void> initialize() async {
    await _fetchCompanyId();
    await _initializeMembers();
  }

  Future<void> _fetchCompanyId() async {
    companyId = await gateStorage.getSocietyId();
    final companyDetails = await gateStorage.getSocietyDetails();
    companyName = companyDetails['societyName'];
  }

  Future<void> _initializeMembers() async {
    allMembers = await remoteDataSource.getMembersList();
    filteredMembersNotifier.value = allMembers;
  }

  void filterMembers(String query) {
    if (query.length >= 3) {
      filteredMembersNotifier.value = allMembers.where((member) {
        final memberName = member['member_name']
                ?.toLowerCase()
                .contains(query.toLowerCase()) ??
            false;
        final unitNumber = member['unit_flat_number']
                ?.toLowerCase()
                .contains(query.toLowerCase()) ??
            false;
        return memberName || unitNumber;
      }).toList();
    } else {
      filteredMembersNotifier.value = allMembers;
    }
  }

  Future<void> handleMemberSelection(
    String firstName,
    String userId,
    dynamic memberId,
    String buildingUnit,
    dynamic unitId,
    String? memberMobileNo,
  ) async {
    final updatedMembers = Set<String>.from(selectedMembersNotifier.value);

    if (selectedMembersNotifier.value.contains(firstName)) {
      updatedMembers.remove(firstName);
      selectedUserIds.remove(userId);
      _removeMemberId(memberId);
      selectedBuildingUnits.remove(buildingUnit);
      formattedMemberDetails.removeWhere((member) => member.name == firstName);
    } else {
      updatedMembers.add(firstName);
      selectedUserIds.add(userId);
      _addSingleMemberId(memberId);
      selectedBuildingUnits.add(buildingUnit);

      formattedMemberDetails.add(MemberModel(
        name: firstName,
        unitId: unitId.toString(),
        memberId: int.parse(memberId.toString()),
        buildingUnit: buildingUnit,
        mobileNumber: memberMobileNo,
      ));
    }

    selectedMembersNotifier.value = updatedMembers;
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
            print("Error parsing member ID: $id, Error: $e");
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
            print("Error removing member ID: $id, Error: $e");
          }
        }
      }
    }
  }

  Future<void> saveMemberDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final memberDetailsJson = jsonEncode(
      formattedMemberDetails.map((member) => member.toJson()).toList(),
    );
    await prefs.setString('member_details', memberDetailsJson);
  }

  void dispose() {
    filteredMembersNotifier.dispose();
    selectedMembersNotifier.dispose();
    selectedUnitsNotifier.dispose();
  }
}
