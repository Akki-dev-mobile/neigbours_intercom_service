/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

class StaffCompanies extends _i1.SerializableEntity {
  StaffCompanies({
    this.id,
    required this.member_staff_id,
    required this.company_id,
  });

  factory StaffCompanies.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return StaffCompanies(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      member_staff_id: serializationManager
          .deserialize<int>(jsonSerialization['member_staff_id']),
      company_id: serializationManager
          .deserialize<int>(jsonSerialization['company_id']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int member_staff_id;

  int company_id;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'member_staff_id': member_staff_id,
      'company_id': company_id,
    };
  }
}
