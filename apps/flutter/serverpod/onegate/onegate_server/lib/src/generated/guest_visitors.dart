/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class GuestVisitors extends _i1.TableRow {
  GuestVisitors({
    int? id,
    required this.visitor_id,
    required this.guest_name,
    required this.guest_coming_from,
    required this.guest_count,
  }) : super(id);

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

  static final t = GuestVisitorsTable();

  int visitor_id;

  String guest_name;

  String guest_coming_from;

  int guest_count;

  @override
  String get tableName => 'guest_visitors';
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

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'guest_name': guest_name,
      'guest_coming_from': guest_coming_from,
      'guest_count': guest_count,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'guest_name': guest_name,
      'guest_coming_from': guest_coming_from,
      'guest_count': guest_count,
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
      case 'guest_name':
        guest_name = value;
        return;
      case 'guest_coming_from':
        guest_coming_from = value;
        return;
      case 'guest_count':
        guest_count = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<GuestVisitors>> find(
    _i1.Session session, {
    GuestVisitorsExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<GuestVisitors>(
      where: where != null ? where(GuestVisitors.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<GuestVisitors?> findSingleRow(
    _i1.Session session, {
    GuestVisitorsExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<GuestVisitors>(
      where: where != null ? where(GuestVisitors.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<GuestVisitors?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<GuestVisitors>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required GuestVisitorsExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<GuestVisitors>(
      where: where(GuestVisitors.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    GuestVisitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    GuestVisitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    GuestVisitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    GuestVisitorsExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<GuestVisitors>(
      where: where != null ? where(GuestVisitors.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef GuestVisitorsExpressionBuilder = _i1.Expression Function(
    GuestVisitorsTable);

class GuestVisitorsTable extends _i1.Table {
  GuestVisitorsTable() : super(tableName: 'guest_visitors');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final visitor_id = _i1.ColumnInt('visitor_id');

  final guest_name = _i1.ColumnString('guest_name');

  final guest_coming_from = _i1.ColumnString('guest_coming_from');

  final guest_count = _i1.ColumnInt('guest_count');

  @override
  List<_i1.Column> get columns => [
        id,
        visitor_id,
        guest_name,
        guest_coming_from,
        guest_count,
      ];
}

@Deprecated('Use GuestVisitorsTable.t instead.')
GuestVisitorsTable tGuestVisitors = GuestVisitorsTable();
