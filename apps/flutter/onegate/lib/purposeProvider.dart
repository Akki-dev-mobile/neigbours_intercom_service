import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain/entities/visitor/purpose/purpose.dart';
class PurposeProvider extends ChangeNotifier {
  List<PurposeCategory1>? _purposes = [];
  bool _isLoading = false;
  bool _isPurposeToggleOn = false;

  List<PurposeCategory1>? get purposes => _purposes;
  bool get isLoading => _isLoading;
  bool get isPurposeToggleOn => _isPurposeToggleOn;

  PurposeProvider() {
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    _isPurposeToggleOn = prefs.getBool('purpose_toggle') ?? false;

    try {
      final jsonString = prefs.getString('selected_purposes');
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        _purposes = jsonList.map((json) => PurposeCategory1.fromJson(json)).toList();

        print("this is$_purposes");

        for (var purpose in _purposes ?? []) {
          debugPrint('Purpose: ${purpose.categoryName}');
          debugPrint('Subcategories count: ${purpose.subCategories?.length ?? 0}');
          if (purpose.subCategories != null) {
            for (var sub in purpose.subCategories!) {
              debugPrint('  - ${sub.subCategoryName}');
            }
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading purposes: $e');
      debugPrint('Stack trace: $stackTrace');
    }
    notifyListeners();
  }

  Future<void> fetchPurposes(RemoteDataSource remoteDataSource) async {
    _isLoading = true;
    notifyListeners();

    try {
      final fetchedPurposes = await remoteDataSource.fetchPurpose();
      if (fetchedPurposes != null && fetchedPurposes.isNotEmpty) {
        _purposes = fetchedPurposes.map((purpose) {
          if (purpose.subCategories != null) {
            purpose.subCategories = purpose.subCategories!.map((subCat) => SubCategory(
              subCategoryId: subCat.subCategoryId,
              subCategoryName: subCat.subCategoryName,
              image: subCat.image,
              isSelected: subCat.isSelected,
            )).toList();
          }
          return purpose;
        }).toList();

        debugPrint("Purposes fetched successfully: ${_purposes!.length}");
        for (var purpose in _purposes!) {
          debugPrint("Purpose: ${purpose.categoryName}, Subcategories: ${purpose.subCategories?.length ?? 0}");
        }

        await saveSelectedPurposes(_purposes!);
      }
    } catch (e) {
      debugPrint("Failed to fetch purposes: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPurposeToggleState(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _isPurposeToggleOn = value;
    await prefs.setBool('purpose_toggle', value);
    notifyListeners();
  }
  Future<void> saveSelectedPurposes(List<PurposeCategory1> purposes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(purposes.map((p) {
        final json = p.toJson();
        // Ensure subcategories are properly serialized
        if (p.subCategories != null) {
          json['sub_categories'] = p.subCategories!.map((s) => s.toJson()).toList();
        }
        return json;
      }).toList());

      await prefs.setString('selected_purposes', jsonString);
      _purposes = purposes;
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to save purposes: $e");
    }
  }


  void updatePurposeSelection(int index, bool isSelected) {
    if (_purposes != null && index >= 0 && index < _purposes!.length) {
      _purposes![index].isSelected = isSelected;
      notifyListeners();
    }
  }

  // Future<void> fetchPurposes(RemoteDataSource remoteDataSource) async {
  //   _isLoading = true;
  //   notifyListeners();
  //
  //   try {
  //     final fetchedPurposes = await remoteDataSource.fetchPurpose();
  //     if (fetchedPurposes != null && fetchedPurposes.isNotEmpty) {
  //       _purposes = fetchedPurposes;
  //       debugPrint("Purposes fetched successfully: ${_purposes!.length}");
  //     } else {
  //       debugPrint("No purposes returned from the API.");
  //     }
  //   } catch (e) {
  //     debugPrint("Failed to fetch purposes: $e");
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }

  Future<void> clearSavedPurposes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_purposes');
      _purposes = [];
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to clear purposes: $e");
    }
  }
}