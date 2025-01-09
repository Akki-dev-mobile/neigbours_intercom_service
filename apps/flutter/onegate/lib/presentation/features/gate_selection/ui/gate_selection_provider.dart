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

      gates = fetchedGates.map((gate) {
        return {
          ...Map<String, dynamic>.from(gate),
          'isSelected': false, // Default to false
        };
      }).toList();

      // Load the selected gate from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName = prefs.getString(selectedGateKey);

      if (selectedGateName != null) {
        log("Previously Selected Gate: $selectedGateName");

        selectedGate = gates.firstWhere(
              (gate) => gate['gate_name'] == selectedGateName,
          orElse: () {
            // Fallback to the first gate if not found
            gates[0]['isSelected'] = true;
            return gates[0]; // Explicitly return the first gate
          },
        );

        if (selectedGate != null) {
          selectedGate!['isSelected'] = true;
          log("Selected Gate Found: ${selectedGate!['gate_name']}");
        }
      } else if (gates.length == 1) {
        log("Only one gate available: ${gates[0]['gate_name']}");
        gates[0]['isSelected'] = true;
        selectedGate = gates[0];
        await prefs.setString(selectedGateKey, gates[0]['gate_name']);
      } else {
        log("Multiple gates found, defaulting to the first gate.");
        gates[0]['isSelected'] = true;
        selectedGate = gates[0];
      }

      log("Final Selected Gate: ${selectedGate?['gate_name']}");
    } catch (e, stackTrace) {
      log('Error loading gates: $e');
      log('Stack trace: $stackTrace');
      selectedGate = null; // Reset selectedGate on failure
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