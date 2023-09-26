/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

class VisitorCompanyBuildings extends _i1.SerializableEntity {
  VisitorCompanyBuildings({
    this.id,
    required this.visitor_company_id,
    required this.building_id,
  });

  factory VisitorCompanyBuildings.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return VisitorCompanyBuildings(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      visitor_company_id: serializationManager
          .deserialize<int>(jsonSerialization['visitor_company_id']),
      building_id: serializationManager
          .deserialize<int>(jsonSerialization['building_id']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int visitor_company_id;

  int building_id;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_company_id': visitor_company_id,
      'building_id': building_id,
    };
  }
}
