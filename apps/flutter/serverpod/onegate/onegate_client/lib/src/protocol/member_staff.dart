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
    required this.mobile,
    required this.id_proof,
    required this.id_proof_number,
    required this.id_proof_image,
    required this.staff_category_id,
    required this.staff_sub_category_id,
    required this.building_assignment,
  });

  factory MemberStaff.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return MemberStaff(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      name: serializationManager.deserialize<String>(jsonSerialization['name']),
      mobile:
          serializationManager.deserialize<String>(jsonSerialization['mobile']),
      id_proof: serializationManager
          .deserialize<String>(jsonSerialization['id_proof']),
      id_proof_number: serializationManager
          .deserialize<String>(jsonSerialization['id_proof_number']),
      id_proof_image: serializationManager
          .deserialize<String>(jsonSerialization['id_proof_image']),
      staff_category_id: serializationManager
          .deserialize<int>(jsonSerialization['staff_category_id']),
      staff_sub_category_id: serializationManager
          .deserialize<int>(jsonSerialization['staff_sub_category_id']),
      building_assignment:
          serializationManager.deserialize<List<_i2.BuildingAssignment>>(
              jsonSerialization['building_assignment']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String name;

  String mobile;

  String id_proof;

  String id_proof_number;

  String id_proof_image;

  int staff_category_id;

  int staff_sub_category_id;

  List<_i2.BuildingAssignment> building_assignment;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'id_proof': id_proof,
      'id_proof_number': id_proof_number,
      'id_proof_image': id_proof_image,
      'staff_category_id': staff_category_id,
      'staff_sub_category_id': staff_sub_category_id,
      'building_assignment': building_assignment,
    };
  }
}
