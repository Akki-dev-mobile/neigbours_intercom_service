/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'protocol.dart' as _i2;

class MemberStaff extends _i1.SerializableEntity {
  MemberStaff({
    this.id,
    required this.name,
    required this.category_id,
    required this.sub_category_id,
    required this.company_id,
    required this.id_proof_type,
    required this.id_proof_number,
    required this.id_proof_image,
    this.member_staff_building_unit,
  });

  factory MemberStaff.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return MemberStaff(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      name: serializationManager.deserialize<String>(jsonSerialization['name']),
      category_id: serializationManager
          .deserialize<int>(jsonSerialization['category_id']),
      sub_category_id: serializationManager
          .deserialize<int>(jsonSerialization['sub_category_id']),
      company_id: serializationManager
          .deserialize<int>(jsonSerialization['company_id']),
      id_proof_type: serializationManager
          .deserialize<String>(jsonSerialization['id_proof_type']),
      id_proof_number: serializationManager
          .deserialize<String>(jsonSerialization['id_proof_number']),
      id_proof_image: serializationManager
          .deserialize<String>(jsonSerialization['id_proof_image']),
      member_staff_building_unit:
          serializationManager.deserialize<List<_i2.MemberStaffBuildingUnit>?>(
              jsonSerialization['member_staff_building_unit']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String name;

  int category_id;

  int sub_category_id;

  int company_id;

  String id_proof_type;

  String id_proof_number;

  String id_proof_image;

  List<_i2.MemberStaffBuildingUnit>? member_staff_building_unit;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': category_id,
      'sub_category_id': sub_category_id,
      'company_id': company_id,
      'id_proof_type': id_proof_type,
      'id_proof_number': id_proof_number,
      'id_proof_image': id_proof_image,
      'member_staff_building_unit': member_staff_building_unit,
    };
  }
}
