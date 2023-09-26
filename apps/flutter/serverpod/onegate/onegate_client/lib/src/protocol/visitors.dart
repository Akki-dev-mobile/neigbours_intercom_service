/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

class Visitors extends _i1.SerializableEntity {
  Visitors({
    this.id,
    required this.mobile,
    required this.member_category_id,
    required this.visitor_img_url,
    required this.in_gate_id,
    required this.in_time,
    required this.out_gate_id,
    required this.out_time,
    required this.permission_status,
    required this.visitor_count,
    required this.passcode,
    required this.created_at,
    required this.created_by,
    required this.updated_at,
    required this.updated_by,
  });

  factory Visitors.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return Visitors(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      mobile:
          serializationManager.deserialize<String>(jsonSerialization['mobile']),
      member_category_id: serializationManager
          .deserialize<int>(jsonSerialization['member_category_id']),
      visitor_img_url: serializationManager
          .deserialize<String>(jsonSerialization['visitor_img_url']),
      in_gate_id: serializationManager
          .deserialize<int>(jsonSerialization['in_gate_id']),
      in_time: serializationManager
          .deserialize<DateTime>(jsonSerialization['in_time']),
      out_gate_id: serializationManager
          .deserialize<int>(jsonSerialization['out_gate_id']),
      out_time: serializationManager
          .deserialize<DateTime>(jsonSerialization['out_time']),
      permission_status: serializationManager
          .deserialize<String>(jsonSerialization['permission_status']),
      visitor_count: serializationManager
          .deserialize<int>(jsonSerialization['visitor_count']),
      passcode: serializationManager
          .deserialize<String>(jsonSerialization['passcode']),
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

  String mobile;

  int member_category_id;

  String visitor_img_url;

  int in_gate_id;

  DateTime in_time;

  int out_gate_id;

  DateTime out_time;

  String permission_status;

  int visitor_count;

  String passcode;

  DateTime created_at;

  String created_by;

  DateTime updated_at;

  String updated_by;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mobile': mobile,
      'member_category_id': member_category_id,
      'visitor_img_url': visitor_img_url,
      'in_gate_id': in_gate_id,
      'in_time': in_time,
      'out_gate_id': out_gate_id,
      'out_time': out_time,
      'permission_status': permission_status,
      'visitor_count': visitor_count,
      'passcode': passcode,
      'created_at': created_at,
      'created_by': created_by,
      'updated_at': updated_at,
      'updated_by': updated_by,
    };
  }
}
