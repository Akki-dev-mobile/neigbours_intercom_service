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
    final response = await remoteDataSource.getMembersList();
    allMembers = response['data'] as List<dynamic>;
    filteredMembersNotifier.value = allMembers;
  }

  void filterMembers(String query) {
    if (query.length >= 2) {
      final searchQuery = query.toLowerCase().trim();

      // Enhanced multi-field search with smart sorting
      final results = allMembers.where((member) {
        return _matchesMember(member, searchQuery);
      }).toList();

      // Sort results by relevance
      results.sort((a, b) => _calculateRelevanceScore(b, searchQuery)
          .compareTo(_calculateRelevanceScore(a, searchQuery)));

      filteredMembersNotifier.value = results;
    } else {
      filteredMembersNotifier.value = allMembers;
    }
  }

  bool _matchesMember(dynamic member, String searchQuery) {
    // Extract all searchable fields
    final memberName = member['member_name']?.toString().toLowerCase() ?? '';
    final unitNumber =
        member['unit_flat_number']?.toString().toLowerCase() ?? '';
    final buildingUnit =
        member['building_unit']?.toString().toLowerCase() ?? '';

    // Handle member details for first/last name search
    final memberDetails = (member['member_details'] as List<dynamic>?) ??
        (member['rows'] as List<dynamic>?) ??
        [];
    bool nameMatch = false;

    for (final detail in memberDetails) {
      final firstName =
          detail['member_first_name']?.toString().toLowerCase() ?? '';
      final lastName =
          detail['member_last_name']?.toString().toLowerCase() ?? '';
      final fullName = '$firstName $lastName'.trim();

      // Multiple search strategies for names
      if (fullName.contains(searchQuery) ||
          firstName.startsWith(searchQuery) ||
          lastName.startsWith(searchQuery) ||
          firstName.contains(searchQuery) ||
          lastName.contains(searchQuery)) {
        nameMatch = true;
        break;
      }
    }

    // Search across all fields
    return nameMatch ||
        memberName.contains(searchQuery) ||
        unitNumber.contains(searchQuery) ||
        unitNumber.startsWith(searchQuery) ||
        buildingUnit.contains(searchQuery) ||
        buildingUnit.startsWith(searchQuery);
  }

  int _calculateRelevanceScore(dynamic member, String searchQuery) {
    int score = 0;

    final memberName = member['member_name']?.toString().toLowerCase() ?? '';
    final unitNumber =
        member['unit_flat_number']?.toString().toLowerCase() ?? '';
    final buildingUnit =
        member['building_unit']?.toString().toLowerCase() ?? '';

    // Unit number exact match gets highest priority
    if (unitNumber == searchQuery)
      score += 100;
    else if (unitNumber.startsWith(searchQuery))
      score += 80;
    else if (unitNumber.contains(searchQuery)) score += 40;

    // Building unit matches
    if (buildingUnit == searchQuery)
      score += 60;
    else if (buildingUnit.startsWith(searchQuery))
      score += 40;
    else if (buildingUnit.contains(searchQuery)) score += 20;

    // Name matches
    final memberDetails = (member['member_details'] as List<dynamic>?) ??
        (member['rows'] as List<dynamic>?) ??
        [];
    for (final detail in memberDetails) {
      final firstName =
          detail['member_first_name']?.toString().toLowerCase() ?? '';
      final lastName =
          detail['member_last_name']?.toString().toLowerCase() ?? '';
      final fullName = '$firstName $lastName'.trim();

      if (fullName.startsWith(searchQuery))
        score += 70;
      else if (firstName.startsWith(searchQuery) ||
          lastName.startsWith(searchQuery))
        score += 50;
      else if (fullName.contains(searchQuery)) score += 30;
    }

    if (memberName.startsWith(searchQuery))
      score += 50;
    else if (memberName.contains(searchQuery)) score += 25;

    return score;
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
    await prefs.setString('rows', memberDetailsJson);
  }

  void dispose() {
    filteredMembersNotifier.dispose();
    selectedMembersNotifier.dispose();
    selectedUnitsNotifier.dispose();
  }
}
