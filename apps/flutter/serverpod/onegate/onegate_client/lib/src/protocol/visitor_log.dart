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
    required this.visitor_id,
    this.visitor,
    required this.visitor_purpose_category_id,
    this.visitor_purpose_sub_category_id,
    this.visitor_building_assignment,
    required this.visitor_count,
    required this.visitor_check_in,
    this.visitor_check_out,
    this.visitor_card_number,
    this.visitor_coming_from,
    this.visitor_card_id,
    required this.company_id,
    required this.is_checked_out,
  });

  factory VisitorLog.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return VisitorLog(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      visitor_id: serializationManager
          .deserialize<int>(jsonSerialization['visitor_id']),
      visitor: serializationManager
          .deserialize<_i2.Visitor?>(jsonSerialization['visitor']),
      visitor_purpose_category_id: serializationManager
          .deserialize<int>(jsonSerialization['visitor_purpose_category_id']),
      visitor_purpose_sub_category_id: serializationManager.deserialize<int?>(
          jsonSerialization['visitor_purpose_sub_category_id']),
      visitor_building_assignment:
          serializationManager.deserialize<List<_i2.BuildingAssignment>?>(
              jsonSerialization['visitor_building_assignment']),
      visitor_count: serializationManager
          .deserialize<int>(jsonSerialization['visitor_count']),
      visitor_check_in: serializationManager
          .deserialize<DateTime>(jsonSerialization['visitor_check_in']),
      visitor_check_out: serializationManager
          .deserialize<DateTime?>(jsonSerialization['visitor_check_out']),
      visitor_card_number: serializationManager
          .deserialize<String?>(jsonSerialization['visitor_card_number']),
      visitor_coming_from: serializationManager
          .deserialize<String?>(jsonSerialization['visitor_coming_from']),
      visitor_card_id: serializationManager
          .deserialize<int?>(jsonSerialization['visitor_card_id']),
      company_id: serializationManager
          .deserialize<int>(jsonSerialization['company_id']),
      is_checked_out: serializationManager
          .deserialize<bool>(jsonSerialization['is_checked_out']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int visitor_id;

  _i2.Visitor? visitor;

  int visitor_purpose_category_id;

  int? visitor_purpose_sub_category_id;

  List<_i2.BuildingAssignment>? visitor_building_assignment;

  int visitor_count;

  DateTime visitor_check_in;

  DateTime? visitor_check_out;

  String? visitor_card_number;

  String? visitor_coming_from;

  int? visitor_card_id;

  int company_id;

  bool is_checked_out;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'visitor': visitor,
      'visitor_purpose_category_id': visitor_purpose_category_id,
      'visitor_purpose_sub_category_id': visitor_purpose_sub_category_id,
      'visitor_building_assignment': visitor_building_assignment,
      'visitor_count': visitor_count,
      'visitor_check_in': visitor_check_in,
      'visitor_check_out': visitor_check_out,
      'visitor_card_number': visitor_card_number,
      'visitor_coming_from': visitor_coming_from,
      'visitor_card_id': visitor_card_id,
      'company_id': company_id,
      'is_checked_out': is_checked_out,
    };
  }
}
