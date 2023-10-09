/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class PurposeCategory extends _i1.TableRow {
  PurposeCategory({
    int? id,
    required this.purpose_category_name,
    required this.purpose_img,
  }) : super(id);

  factory PurposeCategory.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return PurposeCategory(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      purpose_category_name: serializationManager
          .deserialize<String>(jsonSerialization['purpose_category_name']),
      purpose_img: serializationManager
          .deserialize<String>(jsonSerialization['purpose_img']),
    );
  }

  static final t = PurposeCategoryTable();

  String purpose_category_name;

  String purpose_img;

  @override
  String get tableName => 'purpose_category';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'purpose_category_name': purpose_category_name,
      'purpose_img': purpose_img,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'purpose_category_name': purpose_category_name,
      'purpose_img': purpose_img,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'purpose_category_name': purpose_category_name,
      'purpose_img': purpose_img,
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
      case 'purpose_category_name':
        purpose_category_name = value;
        return;
      case 'purpose_img':
        purpose_img = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<PurposeCategory>> find(
    _i1.Session session, {
    PurposeCategoryExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<PurposeCategory>(
      where: where != null ? where(PurposeCategory.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<PurposeCategory?> findSingleRow(
    _i1.Session session, {
    PurposeCategoryExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<PurposeCategory>(
      where: where != null ? where(PurposeCategory.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<PurposeCategory?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<PurposeCategory>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required PurposeCategoryExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<PurposeCategory>(
      where: where(PurposeCategory.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    PurposeCategory row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    PurposeCategory row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    PurposeCategory row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    PurposeCategoryExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<PurposeCategory>(
      where: where != null ? where(PurposeCategory.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef PurposeCategoryExpressionBuilder = _i1.Expression Function(
    PurposeCategoryTable);

class PurposeCategoryTable extends _i1.Table {
  PurposeCategoryTable() : super(tableName: 'purpose_category');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final purpose_category_name = _i1.ColumnString('purpose_category_name');

  final purpose_img = _i1.ColumnString('purpose_img');

  @override
  List<_i1.Column> get columns => [
        id,
        purpose_category_name,
        purpose_img,
      ];
}

@Deprecated('Use PurposeCategoryTable.t instead.')
PurposeCategoryTable tPurposeCategory = PurposeCategoryTable();
