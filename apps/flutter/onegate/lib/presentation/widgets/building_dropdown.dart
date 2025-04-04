import 'package:flutter/material.dart';

/// A reusable dropdown widget for selecting buildings
///
/// This widget displays a dropdown of building names extracted from unit names
/// (e.g., "TOWER NO 01" from "TOWER NO 01-202") and allows the user to filter
/// by building.
class BuildingDropdown extends StatelessWidget {
  /// The currently selected building
  final String? selectedBuilding;

  /// Callback when a building is selected
  final Function(String?) onBuildingSelected;

  /// List of building names to display in the dropdown
  final List<String> buildingNames;

  const BuildingDropdown({
    Key? key,
    required this.selectedBuilding,
    required this.onBuildingSelected,
    required this.buildingNames,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Sort the building names
    List<String> sortedBuildingNames = List.from(buildingNames)..sort();

    // Make sure "All Buildings" is always the first option
    if (sortedBuildingNames.contains("All Buildings")) {
      sortedBuildingNames.remove("All Buildings");
      sortedBuildingNames.insert(0, "All Buildings");
    }
    Size size = MediaQuery.of(context).size;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: size.width * 0.2, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedBuilding,
          icon: const Icon(Icons.arrow_drop_down),
          elevation: 16,
          style: Theme.of(context).textTheme.bodyMedium,
          onChanged: onBuildingSelected,
          items:
              sortedBuildingNames.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Helper method to extract building names from a list of units or visitors
  ///
  /// This method can be used to extract building names from various data sources
  /// like visitor logs, parcels, etc.
  static Set<String> extractBuildingNames<T>(
    List<T> items, {
    required String Function(T item) getUnitName,
  }) {
    Set<String> buildingNames = {"All Buildings"};

    for (var item in items) {
      final unitName = getUnitName(item);
      if (unitName.isNotEmpty) {
        // Extract building name (e.g., "TOWER NO 01" from "TOWER NO 01-202")
        if (unitName.contains("-")) {
          String buildingName = unitName.split("-")[0].trim();
          buildingNames.add(buildingName);
        } else {
          buildingNames.add(unitName);
        }
      }
    }

    return buildingNames;
  }
}
