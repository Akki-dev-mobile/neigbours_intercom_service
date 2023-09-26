/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

class StaffBuildingUnits extends _i1.SerializableEntity {
  StaffBuildingUnits({
    this.id,
    required this.staff_company_building_id,
    required this.unit_id,
  });

  factory StaffBuildingUnits.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return StaffBuildingUnits(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      staff_company_building_id: serializationManager
          .deserialize<int>(jsonSerialization['staff_company_building_id']),
      unit_id:
          serializationManager.deserialize<int>(jsonSerialization['unit_id']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int staff_company_building_id;

  int unit_id;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staff_company_building_id': staff_company_building_id,
      'unit_id': unit_id,
    };
  }
}
