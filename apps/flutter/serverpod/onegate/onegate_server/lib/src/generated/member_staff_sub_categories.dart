/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class MemberStaffSubCategories extends _i1.TableRow {
  MemberStaffSubCategories({
    int? id,
    required this.name,
    required this.category_id,
  }) : super(id);

  factory MemberStaffSubCategories.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return MemberStaffSubCategories(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      name: serializationManager.deserialize<String>(jsonSerialization['name']),
      category_id: serializationManager
          .deserialize<int>(jsonSerialization['category_id']),
    );
  }

  static final t = MemberStaffSubCategoriesTable();

  String name;

  int category_id;

  @override
  String get tableName => 'member_staff_sub_categories';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': category_id,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'name': name,
      'category_id': category_id,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'name': name,
      'category_id': category_id,
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
      case 'category_id':
        category_id = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<MemberStaffSubCategories>> find(
    _i1.Session session, {
    MemberStaffSubCategoriesExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<MemberStaffSubCategories>(
      where: where != null ? where(MemberStaffSubCategories.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<MemberStaffSubCategories?> findSingleRow(
    _i1.Session session, {
    MemberStaffSubCategoriesExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<MemberStaffSubCategories>(
      where: where != null ? where(MemberStaffSubCategories.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<MemberStaffSubCategories?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<MemberStaffSubCategories>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required MemberStaffSubCategoriesExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<MemberStaffSubCategories>(
      where: where(MemberStaffSubCategories.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    MemberStaffSubCategories row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    MemberStaffSubCategories row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    MemberStaffSubCategories row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    MemberStaffSubCategoriesExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<MemberStaffSubCategories>(
      where: where != null ? where(MemberStaffSubCategories.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef MemberStaffSubCategoriesExpressionBuilder = _i1.Expression Function(
    MemberStaffSubCategoriesTable);

class MemberStaffSubCategoriesTable extends _i1.Table {
  MemberStaffSubCategoriesTable()
      : super(tableName: 'member_staff_sub_categories');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final name = _i1.ColumnString('name');

  final category_id = _i1.ColumnInt('category_id');

  @override
  List<_i1.Column> get columns => [
        id,
        name,
        category_id,
      ];
}

@Deprecated('Use MemberStaffSubCategoriesTable.t instead.')
MemberStaffSubCategoriesTable tMemberStaffSubCategories =
    MemberStaffSubCategoriesTable();
