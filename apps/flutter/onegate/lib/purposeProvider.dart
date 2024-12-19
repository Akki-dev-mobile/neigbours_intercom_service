import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/purpose_mapper.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurposeProvider extends ChangeNotifier {
  List<PurposeCategory>? _purposes = [];
  bool _isLoading = false;
  bool _isPurposeToggleOn = false;

  List<PurposeCategory>? get purposes => _purposes;
  bool get isLoading => _isLoading;
  bool get isPurposeToggleOn => _isPurposeToggleOn;

  PurposeProvider() {
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    // Load toggle state
    final prefs = await SharedPreferences.getInstance();
    _isPurposeToggleOn = prefs.getBool('purpose_toggle') ?? false;

    // Load selected purposes
    final jsonString = prefs.getString('selected_purposes');
    if (jsonString != null) {
      final jsonList = jsonDecode(jsonString) as List;
      _purposes =
          jsonList.map((json) => PurposeCategoryMapper.fromJson(json)).toList();
    }
    notifyListeners();
  }

  Future<void> setPurposeToggleState(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _isPurposeToggleOn = value;
    await prefs.setBool('purpose_toggle', value);
    notifyListeners();
  }

  Future<void> saveSelectedPurposes(
      List<PurposeCategory> selectedPurposes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString =
          jsonEncode(selectedPurposes.map((p) => p.toJson()).toList());
      await prefs.setString('selected_purposes', jsonString);
      _purposes = selectedPurposes;
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to save purposes: $e");
    }
  }

  Future<void> fetchPurposes(RemoteDataSource remoteDataSource) async {
    _isLoading = true;
    notifyListeners(); // Notify that loading started

    try {
      final fetchedPurposes = await remoteDataSource.fetchPurpose();
      if (fetchedPurposes!.isNotEmpty) {
        _purposes = fetchedPurposes;
        debugPrint("Purposes fetched successfully: ${_purposes!.length}");
      } else {
        debugPrint("No purposes returned from the API.");
      }
    } catch (e) {
      debugPrint("Failed to fetch purposes: $e");
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify that loading finished
    }
  }

  void updatePurposeSelection(int index, bool isSelected) {
    _purposes![index].isSelected = isSelected;
    notifyListeners();
  }
}
