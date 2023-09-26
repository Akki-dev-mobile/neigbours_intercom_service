/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class VendorVisitors extends _i1.TableRow {
  VendorVisitors({
    int? id,
    required this.visitor_id,
    required this.vendor_name,
    required this.member_sub_category_id,
  }) : super(id);

  factory VendorVisitors.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return VendorVisitors(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      visitor_id: serializationManager
          .deserialize<int>(jsonSerialization['visitor_id']),
      vendor_name: serializationManager
          .deserialize<String>(jsonSerialization['vendor_name']),
      member_sub_category_id: serializationManager
          .deserialize<String>(jsonSerialization['member_sub_category_id']),
    );
  }

  static final t = VendorVisitorsTable();

  int visitor_id;

  String vendor_name;

  String member_sub_category_id;

  @override
  String get tableName => 'vendor_visitors';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'vendor_name': vendor_name,
      'member_sub_category_id': member_sub_category_id,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'vendor_name': vendor_name,
      'member_sub_category_id': member_sub_category_id,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'vendor_name': vendor_name,
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
      case 'vendor_name':
        vendor_name = value;
        return;
      case 'member_sub_category_id':
        member_sub_category_id = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<VendorVisitors>> find(
    _i1.Session session, {
    VendorVisitorsExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<VendorVisitors>(
      where: where != null ? where(VendorVisitors.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<VendorVisitors?> findSingleRow(
    _i1.Session session, {
    VendorVisitorsExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<VendorVisitors>(
      where: where != null ? where(VendorVisitors.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<VendorVisitors?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<VendorVisitors>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required VendorVisitorsExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<VendorVisitors>(
      where: where(VendorVisitors.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    VendorVisitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    VendorVisitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    VendorVisitors row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    VendorVisitorsExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<VendorVisitors>(
      where: where != null ? where(VendorVisitors.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef VendorVisitorsExpressionBuilder = _i1.Expression Function(
    VendorVisitorsTable);

class VendorVisitorsTable extends _i1.Table {
  VendorVisitorsTable() : super(tableName: 'vendor_visitors');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final visitor_id = _i1.ColumnInt('visitor_id');

  final vendor_name = _i1.ColumnString('vendor_name');

  final member_sub_category_id = _i1.ColumnString('member_sub_category_id');

  @override
  List<_i1.Column> get columns => [
        id,
        visitor_id,
        vendor_name,
        member_sub_category_id,
      ];
}

@Deprecated('Use VendorVisitorsTable.t instead.')
VendorVisitorsTable tVendorVisitors = VendorVisitorsTable();
