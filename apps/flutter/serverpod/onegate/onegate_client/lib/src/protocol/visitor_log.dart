/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'protocol.dart' as _i2;

class VisitorLog extends _i1.SerializableEntity {
  VisitorLog({
    this.id,
    required this.visitor,
    required this.visitor_purpose_category_id,
    required this.visitor_purpose_sub_category_id,
    required this.visitor_building_assignment,
    required this.visitor_image,
    required this.visitor_count,
    required this.visitor_check_in,
    required this.visitor_check_out,
    required this.visitor_card_number,
    required this.visitor_card_id,
    required this.company_id,
  });

  factory VisitorLog.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return VisitorLog(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      visitor: serializationManager
          .deserialize<_i2.Visitor>(jsonSerialization['visitor']),
      visitor_purpose_category_id: serializationManager
          .deserialize<int>(jsonSerialization['visitor_purpose_category_id']),
      visitor_purpose_sub_category_id: serializationManager.deserialize<int>(
          jsonSerialization['visitor_purpose_sub_category_id']),
      visitor_building_assignment:
          serializationManager.deserialize<List<_i2.BuildingAssignment>>(
              jsonSerialization['visitor_building_assignment']),
      visitor_image: serializationManager
          .deserialize<String>(jsonSerialization['visitor_image']),
      visitor_count: serializationManager
          .deserialize<int>(jsonSerialization['visitor_count']),
      visitor_check_in: serializationManager
          .deserialize<DateTime>(jsonSerialization['visitor_check_in']),
      visitor_check_out: serializationManager
          .deserialize<DateTime>(jsonSerialization['visitor_check_out']),
      visitor_card_number: serializationManager
          .deserialize<String>(jsonSerialization['visitor_card_number']),
      visitor_card_id: serializationManager
          .deserialize<int>(jsonSerialization['visitor_card_id']),
      company_id: serializationManager
          .deserialize<int>(jsonSerialization['company_id']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  _i2.Visitor visitor;

  int visitor_purpose_category_id;

  int visitor_purpose_sub_category_id;

  List<_i2.BuildingAssignment> visitor_building_assignment;

  String visitor_image;

  int visitor_count;

  DateTime visitor_check_in;

  DateTime visitor_check_out;

  String visitor_card_number;

  int visitor_card_id;

  int company_id;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor': visitor,
      'visitor_purpose_category_id': visitor_purpose_category_id,
      'visitor_purpose_sub_category_id': visitor_purpose_sub_category_id,
      'visitor_building_assignment': visitor_building_assignment,
      'visitor_image': visitor_image,
      'visitor_count': visitor_count,
      'visitor_check_in': visitor_check_in,
      'visitor_check_out': visitor_check_out,
      'visitor_card_number': visitor_card_number,
      'visitor_card_id': visitor_card_id,
      'company_id': company_id,
    };
  }
}
