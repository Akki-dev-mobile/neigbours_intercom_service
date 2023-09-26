/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class TransportVisitors extends _i1.TableRow {
  TransportVisitors({
    int? id,
    required this.visitor_id,
    required this.driver_name,
  }) : super(id);

  factory TransportVisitors.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return TransportVisitors(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      visitor_id: serializationManager
          .deserialize<int>(jsonSerialization['visitor_id']),
      driver_name: serializationManager
          .deserialize<int>(jsonSerialization['driver_name']),
    );
  }

  static final t = TransportVisitorsTable();

  int visitor_id;

  int driver_name;

  @override
  String get tableName => 'transport_visitors';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'driver_name': driver_name,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'driver_name': driver_name,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'driver_name': driver_name,
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
      case 'driver_name':
        driver_name = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<TransportVisitors>> find(
    _i1.Session session, {
    TransportVisitorsExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<TransportVisitors>(
      where: where != null ? where(TransportVisitors.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<TransportVisitors?> findSingleRow(
    _i1.Session session, {
    TransportVisitorsExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<TransportVisitors>(
      where: where != null ? where(TransportVisitors.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<TransportVisitors?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<TransportVisitors>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required TransportVisitorsExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<TransportVisitors>(
      where: where(TransportVisitors.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    TransportVisitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    TransportVisitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    TransportVisitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    TransportVisitorsExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<TransportVisitors>(
      where: where != null ? where(TransportVisitors.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef TransportVisitorsExpressionBuilder = _i1.Expression Function(
    TransportVisitorsTable);

class TransportVisitorsTable extends _i1.Table {
  TransportVisitorsTable() : super(tableName: 'transport_visitors');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final visitor_id = _i1.ColumnInt('visitor_id');

  final driver_name = _i1.ColumnInt('driver_name');

  @override
  List<_i1.Column> get columns => [
        id,
        visitor_id,
        driver_name,
      ];
}

@Deprecated('Use TransportVisitorsTable.t instead.')
TransportVisitorsTable tTransportVisitors = TransportVisitorsTable();
