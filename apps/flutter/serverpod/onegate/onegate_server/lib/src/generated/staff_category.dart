/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class StaffCategory extends _i1.TableRow {
  StaffCategory({
    int? id,
    required this.category_name,
  }) : super(id);

  factory StaffCategory.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return StaffCategory(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      category_name: serializationManager
          .deserialize<String>(jsonSerialization['category_name']),
    );
  }

  static final t = StaffCategoryTable();

  String category_name;

  @override
  String get tableName => 'staff_categories';

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_name': category_name,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'category_name': category_name,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'category_name': category_name,
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
      case 'category_name':
        category_name = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<StaffCategory>> find(
    _i1.Session session, {
    StaffCategoryExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<StaffCategory>(
      where: where != null ? where(StaffCategory.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<StaffCategory?> findSingleRow(
    _i1.Session session, {
    StaffCategoryExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<StaffCategory>(
      where: where != null ? where(StaffCategory.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<StaffCategory?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<StaffCategory>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required StaffCategoryExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<StaffCategory>(
      where: where(StaffCategory.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    StaffCategory row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    StaffCategory row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    StaffCategory row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    StaffCategoryExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<StaffCategory>(
      where: where != null ? where(StaffCategory.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef StaffCategoryExpressionBuilder = _i1.Expression Function(
    StaffCategoryTable);

class StaffCategoryTable extends _i1.Table {
  StaffCategoryTable() : super(tableName: 'staff_categories');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final category_name = _i1.ColumnString('category_name');

  @override
  List<_i1.Column> get columns => [
        id,
        category_name,
      ];
}

@Deprecated('Use StaffCategoryTable.t instead.')
StaffCategoryTable tStaffCategory = StaffCategoryTable();
