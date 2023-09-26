/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

class DeliveryVisitors extends _i1.SerializableEntity {
  DeliveryVisitors({
    this.id,
    required this.visitor_id,
    required this.delivery_person_name,
    required this.delivery_comapny,
  });

  factory DeliveryVisitors.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return DeliveryVisitors(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      visitor_id: serializationManager
          .deserialize<int>(jsonSerialization['visitor_id']),
      delivery_person_name: serializationManager
          .deserialize<String>(jsonSerialization['delivery_person_name']),
      delivery_comapny: serializationManager
          .deserialize<String>(jsonSerialization['delivery_comapny']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int visitor_id;

  String delivery_person_name;

  String delivery_comapny;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'delivery_person_name': delivery_person_name,
      'delivery_comapny': delivery_comapny,
    };
  }
}
