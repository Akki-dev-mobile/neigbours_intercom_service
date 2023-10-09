/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

class PurposeSubCategory extends _i1.SerializableEntity {
  PurposeSubCategory({
    this.id,
    required this.purpose_category_id,
    required this.purpose_sub_category_name,
    required this.purpose_img,
  });

  factory PurposeSubCategory.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return PurposeSubCategory(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      purpose_category_id: serializationManager
          .deserialize<int>(jsonSerialization['purpose_category_id']),
      purpose_sub_category_name: serializationManager
          .deserialize<String>(jsonSerialization['purpose_sub_category_name']),
      purpose_img: serializationManager
          .deserialize<String>(jsonSerialization['purpose_img']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int purpose_category_id;

  String purpose_sub_category_name;

  String purpose_img;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'purpose_category_id': purpose_category_id,
      'purpose_sub_category_name': purpose_sub_category_name,
      'purpose_img': purpose_img,
    };
  }
}
