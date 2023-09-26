/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class StaffCompanies extends _i1.TableRow {
  StaffCompanies({
    int? id,
    required this.member_staff_id,
    required this.company_id,
  }) : super(id);

  factory StaffCompanies.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return StaffCompanies(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      member_staff_id: serializationManager
          .deserialize<int>(jsonSerialization['member_staff_id']),
      company_id: serializationManager
          .deserialize<int>(jsonSerialization['company_id']),
    );
  }

  static final t = StaffCompaniesTable();

  int member_staff_id;

  int company_id;

  @override
  String get tableName => 'staff_companies';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'member_staff_id': member_staff_id,
      'company_id': company_id,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'member_staff_id': member_staff_id,
      'company_id': company_id,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'member_staff_id': member_staff_id,
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
      case 'member_staff_id':
        member_staff_id = value;
        return;
      case 'company_id':
        company_id = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<StaffCompanies>> find(
    _i1.Session session, {
    StaffCompaniesExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<StaffCompanies>(
      where: where != null ? where(StaffCompanies.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<StaffCompanies?> findSingleRow(
    _i1.Session session, {
    StaffCompaniesExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<StaffCompanies>(
      where: where != null ? where(StaffCompanies.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<StaffCompanies?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<StaffCompanies>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required StaffCompaniesExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<StaffCompanies>(
      where: where(StaffCompanies.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    StaffCompanies row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    StaffCompanies row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    StaffCompanies row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    StaffCompaniesExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<StaffCompanies>(
      where: where != null ? where(StaffCompanies.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef StaffCompaniesExpressionBuilder = _i1.Expression Function(
    StaffCompaniesTable);

class StaffCompaniesTable extends _i1.Table {
  StaffCompaniesTable() : super(tableName: 'staff_companies');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final member_staff_id = _i1.ColumnInt('member_staff_id');

  final company_id = _i1.ColumnInt('company_id');

  @override
  List<_i1.Column> get columns => [
        id,
        member_staff_id,
        company_id,
      ];
}

@Deprecated('Use StaffCompaniesTable.t instead.')
StaffCompaniesTable tStaffCompanies = StaffCompaniesTable();
