/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class VerificationTypes extends _i1.TableRow {
  VerificationTypes({
    int? id,
    required this.name,
    required this.status,
    required this.created_at,
    required this.updated_at,
  }) : super(id);

  factory VerificationTypes.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return VerificationTypes(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      name: serializationManager.deserialize<String>(jsonSerialization['name']),
      status:
          serializationManager.deserialize<String>(jsonSerialization['status']),
      created_at: serializationManager
          .deserialize<DateTime>(jsonSerialization['created_at']),
      updated_at: serializationManager
          .deserialize<DateTime>(jsonSerialization['updated_at']),
    );
  }

  static final t = VerificationTypesTable();

  String name;

  String status;

  DateTime created_at;

  DateTime updated_at;

  @override
  String get tableName => 'verification_types';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'created_at': created_at,
      'updated_at': updated_at,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'created_at': created_at,
      'updated_at': updated_at,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'created_at': created_at,
      'updated_at': updated_at,
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
      case 'name':
        name = value;
        return;
      case 'status':
        status = value;
        return;
      case 'created_at':
        created_at = value;
        return;
      case 'updated_at':
        updated_at = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<VerificationTypes>> find(
    _i1.Session session, {
    VerificationTypesExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<VerificationTypes>(
      where: where != null ? where(VerificationTypes.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<VerificationTypes?> findSingleRow(
    _i1.Session session, {
    VerificationTypesExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<VerificationTypes>(
      where: where != null ? where(VerificationTypes.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<VerificationTypes?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<VerificationTypes>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required VerificationTypesExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<VerificationTypes>(
      where: where(VerificationTypes.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    VerificationTypes row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    VerificationTypes row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    VerificationTypes row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    VerificationTypesExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<VerificationTypes>(
      where: where != null ? where(VerificationTypes.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef VerificationTypesExpressionBuilder = _i1.Expression Function(
    VerificationTypesTable);

class VerificationTypesTable extends _i1.Table {
  VerificationTypesTable() : super(tableName: 'verification_types');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final name = _i1.ColumnString('name');

  final status = _i1.ColumnString('status');

  final created_at = _i1.ColumnDateTime('created_at');

  final updated_at = _i1.ColumnDateTime('updated_at');

  @override
  List<_i1.Column> get columns => [
        id,
        name,
        status,
        created_at,
        updated_at,
      ];
}

@Deprecated('Use VerificationTypesTable.t instead.')
VerificationTypesTable tVerificationTypes = VerificationTypesTable();
