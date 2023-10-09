/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

class VisitorCard extends _i1.SerializableEntity {
  VisitorCard({
    this.id,
    required this.visitor_card_number,
    required this.visitor_card_is_assigned,
  });

  factory VisitorCard.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return VisitorCard(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      visitor_card_number: serializationManager
          .deserialize<String>(jsonSerialization['visitor_card_number']),
      visitor_card_is_assigned: serializationManager
          .deserialize<bool>(jsonSerialization['visitor_card_is_assigned']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String visitor_card_number;

  bool visitor_card_is_assigned;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_card_number': visitor_card_number,
      'visitor_card_is_assigned': visitor_card_is_assigned,
    };
  }
}
