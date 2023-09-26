/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class VisitorCompanies extends _i1.TableRow {
  VisitorCompanies({
    int? id,
    required this.visitor_id,
    required this.company_id,
  }) : super(id);

  factory VisitorCompanies.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return VisitorCompanies(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      visitor_id: serializationManager
          .deserialize<int>(jsonSerialization['visitor_id']),
      company_id: serializationManager
          .deserialize<int>(jsonSerialization['company_id']),
    );
  }

  static final t = VisitorCompaniesTable();

  int visitor_id;

  int company_id;

  @override
  String get tableName => 'visitor_companies';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'company_id': company_id,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'company_id': company_id,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'company_id': company_id,
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
      case 'company_id':
        company_id = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<VisitorCompanies>> find(
    _i1.Session session, {
    VisitorCompaniesExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<VisitorCompanies>(
      where: where != null ? where(VisitorCompanies.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<VisitorCompanies?> findSingleRow(
    _i1.Session session, {
    VisitorCompaniesExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<VisitorCompanies>(
      where: where != null ? where(VisitorCompanies.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<VisitorCompanies?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<VisitorCompanies>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required VisitorCompaniesExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<VisitorCompanies>(
      where: where(VisitorCompanies.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    VisitorCompanies row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    VisitorCompanies row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    VisitorCompanies row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    VisitorCompaniesExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<VisitorCompanies>(
      where: where != null ? where(VisitorCompanies.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef VisitorCompaniesExpressionBuilder = _i1.Expression Function(
    VisitorCompaniesTable);

class VisitorCompaniesTable extends _i1.Table {
  VisitorCompaniesTable() : super(tableName: 'visitor_companies');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final visitor_id = _i1.ColumnInt('visitor_id');

  final company_id = _i1.ColumnInt('company_id');

  @override
  List<_i1.Column> get columns => [
        id,
        visitor_id,
        company_id,
      ];
}

@Deprecated('Use VisitorCompaniesTable.t instead.')
VisitorCompaniesTable tVisitorCompanies = VisitorCompaniesTable();
