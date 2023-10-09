/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class StaffSubCategory extends _i1.TableRow {
  StaffSubCategory({
    int? id,
    required this.staff_category_id,
    required this.sub_categories_name,
  }) : super(id);

  factory StaffSubCategory.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return StaffSubCategory(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      staff_category_id: serializationManager
          .deserialize<int>(jsonSerialization['staff_category_id']),
      sub_categories_name: serializationManager
          .deserialize<String>(jsonSerialization['sub_categories_name']),
    );
  }

  static final t = StaffSubCategoryTable();

  int staff_category_id;

  String sub_categories_name;

  @override
  String get tableName => 'staff_sub_categories';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staff_category_id': staff_category_id,
      'sub_categories_name': sub_categories_name,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'staff_category_id': staff_category_id,
      'sub_categories_name': sub_categories_name,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'staff_category_id': staff_category_id,
      'sub_categories_name': sub_categories_name,
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
      case 'staff_category_id':
        staff_category_id = value;
        return;
      case 'sub_categories_name':
        sub_categories_name = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<StaffSubCategory>> find(
    _i1.Session session, {
    StaffSubCategoryExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<StaffSubCategory>(
      where: where != null ? where(StaffSubCategory.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<StaffSubCategory?> findSingleRow(
    _i1.Session session, {
    StaffSubCategoryExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<StaffSubCategory>(
      where: where != null ? where(StaffSubCategory.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<StaffSubCategory?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<StaffSubCategory>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required StaffSubCategoryExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<StaffSubCategory>(
      where: where(StaffSubCategory.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    StaffSubCategory row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    StaffSubCategory row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    StaffSubCategory row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    StaffSubCategoryExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<StaffSubCategory>(
      where: where != null ? where(StaffSubCategory.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef StaffSubCategoryExpressionBuilder = _i1.Expression Function(
    StaffSubCategoryTable);

class StaffSubCategoryTable extends _i1.Table {
  StaffSubCategoryTable() : super(tableName: 'staff_sub_categories');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final staff_category_id = _i1.ColumnInt('staff_category_id');

  final sub_categories_name = _i1.ColumnString('sub_categories_name');

  @override
  List<_i1.Column> get columns => [
        id,
        staff_category_id,
        sub_categories_name,
      ];
}

@Deprecated('Use StaffSubCategoryTable.t instead.')
StaffSubCategoryTable tStaffSubCategory = StaffSubCategoryTable();
