/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class StaffVisitors extends _i1.TableRow {
  StaffVisitors({
    int? id,
    required this.visitor_id,
    required this.member_sub_category_id,
  }) : super(id);

  factory StaffVisitors.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return StaffVisitors(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      visitor_id: serializationManager
          .deserialize<int>(jsonSerialization['visitor_id']),
      member_sub_category_id: serializationManager
          .deserialize<String>(jsonSerialization['member_sub_category_id']),
    );
  }

  static final t = StaffVisitorsTable();

  int visitor_id;

  String member_sub_category_id;

  @override
  String get tableName => 'staff_visitors';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'member_sub_category_id': member_sub_category_id,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'member_sub_category_id': member_sub_category_id,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'member_sub_category_id': member_sub_category_id,
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
      case 'member_sub_category_id':
        member_sub_category_id = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<StaffVisitors>> find(
    _i1.Session session, {
    StaffVisitorsExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<StaffVisitors>(
      where: where != null ? where(StaffVisitors.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<StaffVisitors?> findSingleRow(
    _i1.Session session, {
    StaffVisitorsExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<StaffVisitors>(
      where: where != null ? where(StaffVisitors.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<StaffVisitors?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<StaffVisitors>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required StaffVisitorsExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<StaffVisitors>(
      where: where(StaffVisitors.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    StaffVisitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    StaffVisitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    StaffVisitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    StaffVisitorsExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<StaffVisitors>(
      where: where != null ? where(StaffVisitors.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef StaffVisitorsExpressionBuilder = _i1.Expression Function(
    StaffVisitorsTable);

class StaffVisitorsTable extends _i1.Table {
  StaffVisitorsTable() : super(tableName: 'staff_visitors');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final visitor_id = _i1.ColumnInt('visitor_id');

  final member_sub_category_id = _i1.ColumnString('member_sub_category_id');

  @override
  List<_i1.Column> get columns => [
        id,
        visitor_id,
        member_sub_category_id,
      ];
}

@Deprecated('Use StaffVisitorsTable.t instead.')
StaffVisitorsTable tStaffVisitors = StaffVisitorsTable();
