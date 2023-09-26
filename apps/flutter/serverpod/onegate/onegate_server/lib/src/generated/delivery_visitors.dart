/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class DeliveryVisitors extends _i1.TableRow {
  DeliveryVisitors({
    int? id,
    required this.visitor_id,
    required this.delivery_person_name,
    required this.delivery_comapny,
  }) : super(id);

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

  static final t = DeliveryVisitorsTable();

  int visitor_id;

  String delivery_person_name;

  String delivery_comapny;

  @override
  String get tableName => 'delivery_visitors';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'delivery_person_name': delivery_person_name,
      'delivery_comapny': delivery_comapny,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'delivery_person_name': delivery_person_name,
      'delivery_comapny': delivery_comapny,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'delivery_person_name': delivery_person_name,
      'delivery_comapny': delivery_comapny,
    };
  }

  @override
  void setColumn(
    String columnName,
    value,
  ) {
    switch (columnName) {
      case 'id':
        id = value;
        return;
      case 'visitor_id':
        visitor_id = value;
        return;
      case 'delivery_person_name':
        delivery_person_name = value;
        return;
      case 'delivery_comapny':
        delivery_comapny = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<DeliveryVisitors>> find(
    _i1.Session session, {
    DeliveryVisitorsExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<DeliveryVisitors>(
      where: where != null ? where(DeliveryVisitors.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<DeliveryVisitors?> findSingleRow(
    _i1.Session session, {
    DeliveryVisitorsExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<DeliveryVisitors>(
      where: where != null ? where(DeliveryVisitors.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<DeliveryVisitors?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<DeliveryVisitors>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required DeliveryVisitorsExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DeliveryVisitors>(
      where: where(DeliveryVisitors.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    DeliveryVisitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    DeliveryVisitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    DeliveryVisitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    DeliveryVisitorsExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DeliveryVisitors>(
      where: where != null ? where(DeliveryVisitors.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef DeliveryVisitorsExpressionBuilder = _i1.Expression Function(
    DeliveryVisitorsTable);

class DeliveryVisitorsTable extends _i1.Table {
  DeliveryVisitorsTable() : super(tableName: 'delivery_visitors');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final visitor_id = _i1.ColumnInt('visitor_id');

  final delivery_person_name = _i1.ColumnString('delivery_person_name');

  final delivery_comapny = _i1.ColumnString('delivery_comapny');

  @override
  List<_i1.Column> get columns => [
        id,
        visitor_id,
        delivery_person_name,
        delivery_comapny,
      ];
}

@Deprecated('Use DeliveryVisitorsTable.t instead.')
DeliveryVisitorsTable tDeliveryVisitors = DeliveryVisitorsTable();
