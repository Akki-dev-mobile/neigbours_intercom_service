/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

class MemberCategories extends _i1.SerializableEntity {
  MemberCategories({
    this.id,
    required this.name,
    required this.status,
    required this.created_at,
    required this.updated_at,
  });

  factory MemberCategories.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return MemberCategories(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      name: serializationManager.deserialize<String>(jsonSerialization['name']),
      status:
          serializationManager.deserialize<String>(jsonSerialization['status']),
      created_at: serializationManager
          .deserialize<DateTime>(jsonSerialization['created_at']),
      updated_at: serializationManager
          .deserialize<DateTime>(jsonSerialization['updated_at']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String name;

  String status;

  DateTime created_at;

  DateTime updated_at;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'created_at': created_at,
      'updated_at': updated_at,
    };
  }
}
