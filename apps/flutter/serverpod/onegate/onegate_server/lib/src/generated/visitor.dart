/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class Visitor extends _i1.TableRow {
  Visitor({
    int? id,
    required this.name,
    required this.mobile,
    required this.visitor_image,
  }) : super(id);

  factory Visitor.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return Visitor(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      name: serializationManager.deserialize<String>(jsonSerialization['name']),
      mobile:
          serializationManager.deserialize<String>(jsonSerialization['mobile']),
      visitor_image: serializationManager
          .deserialize<String>(jsonSerialization['visitor_image']),
    );
  }

  static final t = VisitorTable();

  String name;

  String mobile;

  String visitor_image;

  @override
  String get tableName => 'visitor';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'visitor_image': visitor_image,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'visitor_image': visitor_image,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'visitor_image': visitor_image,
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
      case 'mobile':
        mobile = value;
        return;
      case 'visitor_image':
        visitor_image = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<Visitor>> find(
    _i1.Session session, {
    VisitorExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<Visitor>(
      where: where != null ? where(Visitor.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<Visitor?> findSingleRow(
    _i1.Session session, {
    VisitorExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<Visitor>(
      where: where != null ? where(Visitor.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<Visitor?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<Visitor>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required VisitorExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<Visitor>(
      where: where(Visitor.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    Visitor row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    Visitor row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    Visitor row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    VisitorExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<Visitor>(
      where: where != null ? where(Visitor.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef VisitorExpressionBuilder = _i1.Expression Function(VisitorTable);

class VisitorTable extends _i1.Table {
  VisitorTable() : super(tableName: 'visitor');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final name = _i1.ColumnString('name');

  final mobile = _i1.ColumnString('mobile');

  final visitor_image = _i1.ColumnString('visitor_image');

  @override
  List<_i1.Column> get columns => [
        id,
        name,
        mobile,
        visitor_image,
      ];
}

@Deprecated('Use VisitorTable.t instead.')
VisitorTable tVisitor = VisitorTable();
