/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

class VisitorCompanyBuildings extends _i1.TableRow {
  VisitorCompanyBuildings({
    int? id,
    required this.visitor_company_id,
    required this.building_id,
  }) : super(id);

  factory VisitorCompanyBuildings.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return VisitorCompanyBuildings(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      visitor_company_id: serializationManager
          .deserialize<int>(jsonSerialization['visitor_company_id']),
      building_id: serializationManager
          .deserialize<int>(jsonSerialization['building_id']),
    );
  }

  static final t = VisitorCompanyBuildingsTable();

  int visitor_company_id;

  int building_id;

  @override
  String get tableName => 'visitor_company_buildings';
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_company_id': visitor_company_id,
      'building_id': building_id,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'visitor_company_id': visitor_company_id,
      'building_id': building_id,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'visitor_company_id': visitor_company_id,
      'building_id': building_id,
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
      case 'visitor_company_id':
        visitor_company_id = value;
        return;
      case 'building_id':
        building_id = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  static Future<List<VisitorCompanyBuildings>> find(
    _i1.Session session, {
    VisitorCompanyBuildingsExpressionBuilder? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<VisitorCompanyBuildings>(
      where: where != null ? where(VisitorCompanyBuildings.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<VisitorCompanyBuildings?> findSingleRow(
    _i1.Session session, {
    VisitorCompanyBuildingsExpressionBuilder? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<VisitorCompanyBuildings>(
      where: where != null ? where(VisitorCompanyBuildings.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  static Future<VisitorCompanyBuildings?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<VisitorCompanyBuildings>(id);
  }

  static Future<int> delete(
    _i1.Session session, {
    required VisitorCompanyBuildingsExpressionBuilder where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<VisitorCompanyBuildings>(
      where: where(VisitorCompanyBuildings.t),
      transaction: transaction,
    );
  }

  static Future<bool> deleteRow(
    _i1.Session session,
    VisitorCompanyBuildings row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  static Future<bool> update(
    _i1.Session session,
    VisitorCompanyBuildings row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  static Future<void> insert(
    _i1.Session session,
    VisitorCompanyBuildings row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  static Future<int> count(
    _i1.Session session, {
    VisitorCompanyBuildingsExpressionBuilder? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<VisitorCompanyBuildings>(
      where: where != null ? where(VisitorCompanyBuildings.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }
}

typedef VisitorCompanyBuildingsExpressionBuilder = _i1.Expression Function(
    VisitorCompanyBuildingsTable);

class VisitorCompanyBuildingsTable extends _i1.Table {
  VisitorCompanyBuildingsTable()
      : super(tableName: 'visitor_company_buildings');

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  final id = _i1.ColumnInt('id');

  final visitor_company_id = _i1.ColumnInt('visitor_company_id');

  final building_id = _i1.ColumnInt('building_id');

  @override
  List<_i1.Column> get columns => [
        id,
        visitor_company_id,
        building_id,
      ];
}

@Deprecated('Use VisitorCompanyBuildingsTable.t instead.')
VisitorCompanyBuildingsTable tVisitorCompanyBuildings =
    VisitorCompanyBuildingsTable();
