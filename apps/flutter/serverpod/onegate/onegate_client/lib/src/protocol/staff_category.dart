/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

class StaffCategory extends _i1.SerializableEntity {
  StaffCategory({
    this.id,
    required this.category_name,
  });

  factory StaffCategory.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return StaffCategory(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      category_name: serializationManager
          .deserialize<String>(jsonSerialization['category_name']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String category_name;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_name': category_name,
    };
  }
}
