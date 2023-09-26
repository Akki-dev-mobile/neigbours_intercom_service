/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class MemberSubCategories extends _i1.TableRow {
  MemberSubCategories({
    int? id,
    required this.name,
    required this.member_category_id,
    required this.status,
    required this.created_at,
    required this.updated_at,
  }) : super(id);

  factory MemberSubCategories.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return MemberSubCategories(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      name: serializationManager.deserialize<String>(jsonSerialization['name']),
      member_category_id: serializationManager
          .deserialize<int>(jsonSerialization['member_category_id']),
      status:
          serializationManager.deserialize<String>(jsonSerialization['status']),
      created_at: serializationManager
          .deserialize<DateTime>(jsonSerialization['created_at']),
      updated_at: serializationManager
          .deserialize<DateTime>(jsonSerialization['updated_at']),
    );
  }

  static final t = MemberSubCategoriesTable();

  String name;

  int member_category_id;

  String status;

  DateTime created_at;

  DateTime updated_at;

  @override
  String get tableName => 'member_sub_categories';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'member_category_id': member_category_id,
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
      'member_category_id': member_category_id,
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
      'member_category_id': member_category_id,
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
      case 'member_category_id':
        member_category_id = value;
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

  static Future<List<MemberSubCategories>> find(
    _i1.Session session, {
    MemberSubCategoriesExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<MemberSubCategories>(
      where: where != null ? where(MemberSubCategories.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<MemberSubCategories?> findSingleRow(
    _i1.Session session, {
    MemberSubCategoriesExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<MemberSubCategories>(
      where: where != null ? where(MemberSubCategories.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<MemberSubCategories?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<MemberSubCategories>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required MemberSubCategoriesExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<MemberSubCategories>(
      where: where(MemberSubCategories.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    MemberSubCategories row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    MemberSubCategories row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    MemberSubCategories row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    MemberSubCategoriesExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<MemberSubCategories>(
      where: where != null ? where(MemberSubCategories.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef MemberSubCategoriesExpressionBuilder = _i1.Expression Function(
    MemberSubCategoriesTable);

class MemberSubCategoriesTable extends _i1.Table {
  MemberSubCategoriesTable() : super(tableName: 'member_sub_categories');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final name = _i1.ColumnString('name');

  final member_category_id = _i1.ColumnInt('member_category_id');

  final status = _i1.ColumnString('status');

  final created_at = _i1.ColumnDateTime('created_at');

  final updated_at = _i1.ColumnDateTime('updated_at');

  @override
  List<_i1.Column> get columns => [
        id,
        name,
        member_category_id,
        status,
        created_at,
        updated_at,
      ];
}

@Deprecated('Use MemberSubCategoriesTable.t instead.')
MemberSubCategoriesTable tMemberSubCategories = MemberSubCategoriesTable();
