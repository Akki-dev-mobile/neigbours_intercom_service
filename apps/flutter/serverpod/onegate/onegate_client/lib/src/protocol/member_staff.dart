/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

class MemberStaff extends _i1.SerializableEntity {
  MemberStaff({
    this.id,
    required this.name,
    required this.phone,
    required this.dob,
    required this.gender,
    required this.member_category_id,
    required this.member_sub_category_id,
    required this.email,
    required this.address,
    required this.verification_type_id,
    required this.verification_number,
    required this.profile_image_url,
    required this.status,
    required this.deleted_by,
    required this.created_at,
    required this.created_by,
    required this.updated_at,
    required this.updated_by,
  });

  factory MemberStaff.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return MemberStaff(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      name: serializationManager.deserialize<String>(jsonSerialization['name']),
      phone:
          serializationManager.deserialize<String>(jsonSerialization['phone']),
      dob: serializationManager.deserialize<DateTime>(jsonSerialization['dob']),
      gender:
          serializationManager.deserialize<String>(jsonSerialization['gender']),
      member_category_id: serializationManager
          .deserialize<int>(jsonSerialization['member_category_id']),
      member_sub_category_id: serializationManager
          .deserialize<int>(jsonSerialization['member_sub_category_id']),
      email:
          serializationManager.deserialize<String>(jsonSerialization['email']),
      address: serializationManager
          .deserialize<String>(jsonSerialization['address']),
      verification_type_id: serializationManager
          .deserialize<int>(jsonSerialization['verification_type_id']),
      verification_number: serializationManager
          .deserialize<String>(jsonSerialization['verification_number']),
      profile_image_url: serializationManager
          .deserialize<String>(jsonSerialization['profile_image_url']),
      status:
          serializationManager.deserialize<String>(jsonSerialization['status']),
      deleted_by: serializationManager
          .deserialize<String>(jsonSerialization['deleted_by']),
      created_at: serializationManager
          .deserialize<DateTime>(jsonSerialization['created_at']),
      created_by: serializationManager
          .deserialize<String>(jsonSerialization['created_by']),
      updated_at: serializationManager
          .deserialize<DateTime>(jsonSerialization['updated_at']),
      updated_by: serializationManager
          .deserialize<String>(jsonSerialization['updated_by']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String name;

  String phone;

  DateTime dob;

  String gender;

  int member_category_id;

  int member_sub_category_id;

  String email;

  String address;

  int verification_type_id;

  String verification_number;

  String profile_image_url;

  String status;

  String deleted_by;

  DateTime created_at;

  String created_by;

  DateTime updated_at;

  String updated_by;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'dob': dob,
      'gender': gender,
      'member_category_id': member_category_id,
      'member_sub_category_id': member_sub_category_id,
      'email': email,
      'address': address,
      'verification_type_id': verification_type_id,
      'verification_number': verification_number,
      'profile_image_url': profile_image_url,
      'status': status,
      'deleted_by': deleted_by,
      'created_at': created_at,
      'created_by': created_by,
      'updated_at': updated_at,
      'updated_by': updated_by,
    };
  }
}
