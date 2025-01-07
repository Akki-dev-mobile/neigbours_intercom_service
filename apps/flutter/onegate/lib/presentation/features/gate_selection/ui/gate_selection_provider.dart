import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GateProvider with ChangeNotifier {
  List<Map<String, dynamic>> gates = [];
  Map<String, dynamic>? selectedGate;
  final RemoteDataSource remoteDataSource;
  bool isLoading = false;

  // SharedPreferences Keys
  static const String selectedGateKey = 'selected_gate';
  static const String numberOfGatesKey = 'number_of_gates';

  GateProvider()
      : remoteDataSource = RemoteDataSource(
    DioSingleton.instance1,
    DioSingleton.instance2,
    DioSingleton.instance3,
  ) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (!isLoading && gates.isEmpty) {
      await loadGates();
    }
  }

  Future<void> loadGates() async {
    isLoading = true; // Start loading
    notifyListeners();

    try {
      // Fetch gates from the remote data source
      final List<dynamic> fetchedGates = await remoteDataSource.fetchGates();
      log("Fetched Gates: $fetchedGates");

      // Cast each gate to Map<String, dynamic> and add `isSelected` field
      gates = fetchedGates.map((gate) {
        return {
          ...Map<String, dynamic>.from(gate), // Explicit cast to Map<String, dynamic>
          'isSelected': false, // Default to false
        };
      }).toList();

      // Load the selected gate from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName = prefs.getString(selectedGateKey);

      if (selectedGateName != null) {
        log("Previously Selected Gate: $selectedGateName");

        // Mark the previously selected gate as `isSelected`
        selectedGate = gates.firstWhere(
              (gate) => gate['gate_name'] == selectedGateName,
          orElse: () {
            log("Selected gate not found, defaulting to first gate.");
            gates[0]['isSelected'] = true;
            return gates[0];
          },
        );
        selectedGate!['isSelected'] = true;
      } else if (gates.isNotEmpty) {
        // Select the first gate by default if no selection exists
        gates[0]['isSelected'] = true;
        selectedGate = gates[0];
      }
    } catch (e, stackTrace) {
      log('Error loading gates: $e');
      log('Stack trace: $stackTrace');
    } finally {
      isLoading = false; // End loading
      notifyListeners();
    }
  }

  Future<void> selectGate(int index) async {
    if (index < 0 || index >= gates.length) return;

    // Deselect all gates and select the specified one
    for (var gate in gates) {
      gate['isSelected'] = false;
    }
    gates[index]['isSelected'] = true;
    selectedGate = gates[index];
    notifyListeners();

    // Save the selected gate to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_gate', gates[index]['gate_name']);
      log("Selected Gate Saved: ${gates[index]['gate_name']}");
    } catch (e, stackTrace) {
      debugPrint('Error saving selected gate: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
}