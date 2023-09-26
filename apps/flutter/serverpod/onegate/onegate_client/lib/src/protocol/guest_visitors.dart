/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

class GuestVisitors extends _i1.SerializableEntity {
  GuestVisitors({
    this.id,
    required this.visitor_id,
    required this.guest_name,
    required this.guest_coming_from,
    required this.guest_count,
  });

  factory GuestVisitors.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return GuestVisitors(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      visitor_id: serializationManager
          .deserialize<int>(jsonSerialization['visitor_id']),
      guest_name: serializationManager
          .deserialize<String>(jsonSerialization['guest_name']),
      guest_coming_from: serializationManager
          .deserialize<String>(jsonSerialization['guest_coming_from']),
      guest_count: serializationManager
          .deserialize<int>(jsonSerialization['guest_count']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int visitor_id;

  String guest_name;

  String guest_coming_from;

  int guest_count;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'guest_name': guest_name,
      'guest_coming_from': guest_coming_from,
      'guest_count': guest_count,
    };
  }
}
